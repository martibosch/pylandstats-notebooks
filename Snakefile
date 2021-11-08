DATA_DIR = "data"
DATA_RAW_DIR = f"{DATA_DIR}/raw"
DATA_PROCESSED_DIR = f"{DATA_DIR}/processed"

NOTEBOOK_DIR = "notebooks"
NOTEBOOK_OUTPUT_DIR = f"{NOTEBOOK_DIR}/output"

data_lulc_dir = f"{DATA_RAW_DIR}/lulc"


checkpoint download_lulc:
    output:
        f"{data_lulc_dir}/noas04-17.zip",
    shell:
        "curl https://www.bfs.admin.ch/bfsstatic/dam/assets/6646411/master -o {output}"


rule lulc_csv:
    input:
        rules.download_lulc.output,
    output:
        f"{data_lulc_dir}/AREA_NOAS04_17_181029.csv",
    shell:
        "unzip -j {input} '*.csv' -d {data_lulc_dir}"


sls_preprocess_filename = "A03-swisslandstats-preprocessing.ipynb"


rule lulc_raster:
    input:
        rules.lulc_csv.output,
    output:
        f"{DATA_PROCESSED_DIR}/veveyse-{{lulc_column}}.tif",
    run:
        shell(
            f"papermill {NOTEBOOK_DIR}/{sls_preprocess_filename} "
            f"{NOTEBOOK_OUTPUT_DIR}/{sls_preprocess_filename} "
            "-p lulc_csv_filepath {input} -p lulc_column {wildcards.lulc_column} "
            "-p dst_filepath {output}"
        )


lulc_columns = ["AS97R_4", "AS09R_4", "AS18_4"]


rule lulc_rasters:
    input:
        expand(rules.lulc_raster.output, lulc_column=lulc_columns),


rule execute_notebook:
    output:
        f"{NOTEBOOK_OUTPUT_DIR}/{{notebook_basename}}.ipynb",
    shell:
        f"papermill {NOTEBOOK_DIR}/{{wildcards.notebook_basename}}.ipynb {{output}} --cwd {NOTEBOOK_DIR}"


notebook_basenames = glob_wildcards(
    f"{NOTEBOOK_DIR}/{{notebook_basename,[^/]+}}.ipynb"
).notebook_basename


rule execute_notebooks:
    input:
        expand(
            rules.execute_notebook.output,
            notebook_basename=notebook_basenames,
        ),


rule all:
    input:
        rules.execute_notebooks.output,
