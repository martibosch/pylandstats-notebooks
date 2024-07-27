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
# LULC_URL = "https://www.bfs.admin.ch/bfsstatic/dam/assets/6646411/master"
# SLS_URL = "https://dam-api.bfs.admin.ch/hub/api/dam/assets/25885691/master"
SLS_DATA_DIR = path.join(DATA_RAW_DIR, "sls")
SLS_PREPROCESS_IPYNB = path.join(
    NOTEBOOKS_DIR, "A03-swisslandstats-preprocessing.ipynb"
)
# ACHTUNG: to pass a list as a papermill parameter we'd need to use a yml file, we are
# thus ommitting this as the notebook already includes the same list of columns as
# default value
LULC_COLUMNS = ["LU85_4", "LU97_4", "LU09_4", "LU18_4"]
VEVEYSE_NOMINATIM_QUERY = "District de la Veveyse, Fribourg, Switzerland"

VEVEYSE_DST_DIR = path.join(DATA_PROCESSED_DIR, "veveyse")


rule veveyse_lulc_tifs:
    input:
        notebook=SLS_PREPROCESS_IPYNB,
    output:
        lulc_tifs=expand(
            path.join(VEVEYSE_DST_DIR, "{lulc_column}.tif"), lulc_column=LULC_COLUMNS
        ),
        notebook=path.join(
            NOTEBOOKS_OUTPUT_DIR,
            "A03-swisslandstats-preprocessing-veveyse.ipynb",
        ),
    shell:
        "papermill {input.notebook} {output.notebook}"
        " -p nominatim_query '{VEVEYSE_NOMINATIM_QUERY}'"
        " -p dst_dir {VEVEYSE_DST_DIR}"


SWITZERLAND_DST_DIR = path.join(DATA_PROCESSED_DIR, "switzerland")


rule switzerland_lulc_tifs:
    input:
        notebook=SLS_PREPROCESS_IPYNB,
    output:
        lulc_tifs=expand(
            path.join(SWITZERLAND_DST_DIR, "{lulc_column}.tif"),
            lulc_column=LULC_COLUMNS,
        ),
        notebook=path.join(
            NOTEBOOKS_OUTPUT_DIR,
            "A03-swisslandstats-preprocessing-switzerland.ipynb",
        ),
    shell:
        "papermill {input.notebook} {output.notebook}"
        " -p dst_dir {SWITZERLAND_DST_DIR}"


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
    "04-spatiotemporal-zonal-analysis.ipynb",
    "05-cluster-analysis.ipynb",
    "A01-fragstats-metrics-comparison.ipynb",
    "A02-performance-notes.ipynb",
    # "A03-swisslandstats-preprocessing.ipynb",
]


rule run_notebook:
    input:
        notebook=path.join(NOTEBOOKS_DIR, "{notebook_filename}"),
    output:
        notebook=path.join(NOTEBOOKS_OUTPUT_DIR, "{notebook_filename}"),
    shell:
        "papermill --cwd {NOTEBOOKS_DIR} {input.notebook} {output.notebook}"


rule run_notebooks:
    input:
        expand(rules.run_notebook.output, notebook_filename=NOTEBOOK_FILENAMES),
    output:
        touch(path.join(NOTEBOOKS_OUTPUT_DIR, "run_notebooks.done")),
