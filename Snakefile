from os import path

PROJECT_NAME = "pylandstats-notebooks"
CODE_DIR = "pylandstats_notebooks"
PYTHON_VERSION = "3.10"

NOTEBOOKS_DIR = "notebooks"
NOTEBOOKS_OUTPUT_DIR = path.join(NOTEBOOKS_DIR, "output")

DATA_DIR = "data"
DATA_RAW_DIR = path.join(DATA_DIR, "raw")
DATA_INTERIM_DIR = path.join(DATA_DIR, "interim")
DATA_PROCESSED_DIR = path.join(DATA_DIR, "processed")


# 0. conda/mamba environment -----------------------------------------------------------
rule create_environment:
    shell:
        "mamba env create -f environment.yml"


rule register_ipykernel:
    shell:
        "python -m ipykernel install --user --name pylandstats --display-name"
        ' "Python (pylandstats)"'


# 1. data preprocessing ----------------------------------------------------------------
# 1.1. land use/land cover data --------------------------------------------------------
LULC_URL = "https://www.bfs.admin.ch/bfsstatic/dam/assets/6646411/master"
LULC_DATA_DIR = path.join(DATA_RAW_DIR, "lulc")


rule download_lulc:
    output:
        temp(path.join(LULC_DATA_DIR, "ag-b-00.03-36-noas04G.zip")),
    shell:
        "curl {LULC_URL} -o {output}"


rule lulc_csv:
    input:
        rules.download_lulc.output,
    output:
        path.join(LULC_DATA_DIR, "AREA_NOAS04_17_181029.csv"),
    run:
        shell("unzip -j {input} '*.csv' -d {LULC_DATA_DIR}")
        shell("touch {output}")


LULC_COLUMNS = ["AS97R_4", "AS09R_4", "AS18_4"]


rule lulc_tif:
    input:
        lulc_csv=rules.lulc_csv.output,
        notebook=path.join(NOTEBOOKS_DIR, "A03-swisslandstats-preprocessing.ipynb"),
    output:
        lulc_tif=path.join(DATA_PROCESSED_DIR, "veveyse-{lulc_column}.tif"),
        notebook=path.join(
            NOTEBOOKS_OUTPUT_DIR,
            "A03-swisslandstats-preprocessing-{lulc_column}.ipynb",
        ),
    shell:
        "papermill {input.notebook} {output.notebook}"
        " -p lulc_csv_filepath {input.lulc_csv}"
        " -p lulc_column {wildcards.lulc_column}"
        " -p dst_filepath {output.lulc_tif}"


rule lulc_tifs:
    input:
        expand(rules.lulc_tif.output, lulc_column=LULC_COLUMNS),


# 1.2. elevation zones
ELEV_ZONES_IPYNB_FILENAME = "A04-elevation-zones.ipynb"
ELEV_ZONES_GPKG_FILEPATH = path.join(DATA_PROCESSED_DIR, "elev-zones.gpkg")


rule elev_zones:
    input:
        notebook=path.join(NOTEBOOKS_DIR, ELEV_ZONES_IPYNB_FILENAME),
    output:
        elev_zones=ELEV_ZONES_GPKG_FILEPATH,
        notebook=path.join(NOTEBOOKS_OUTPUT_DIR, ELEV_ZONES_IPYNB_FILENAME),
    shell:
        "papermill {input.notebook} {output.notebook}"
        " -p dst_filepath {output.elev_zones}"


# 2. notebooks -------------------------------------------------------------------------
NOTEBOOK_FILENAMES = [
    "00-overview.ipynb",
    "01-landscape-analysis.ipynb",
    "02-spatiotemporal-analysis.ipynb",
    "03-zonal-analysis.ipynb",
    "04-spatiotemporal-buffer-analysis.ipynb",
    # "05-cluster-analysis.ipynb",
    "A01-fragstats-metrics-comparison.ipynb",
    "A02-performance-notes.ipynb",
    "A03-swisslandstats-preprocessing.ipynb",
]


rule run_notebook:
    input:
        notebook=path.join(NOTEBOOKS_DIR, "{notebook_filename}"),
    output:
        notebook=path.join(NOTEBOOKS_OUTPUT_DIR, "{notebook_filename}"),
    shell:
        "papermill {input.notebook} {output.notebook}"


rule run_notebooks:
    input:
        expand(rules.run_notebook.output, notebook_filename=NOTEBOOK_FILENAMES),
    output:
        touch(path.join(NOTEBOOKS_OUTPUT_DIR, "run_notebooks.done")),
