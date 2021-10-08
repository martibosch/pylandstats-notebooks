.PHONY: create_environment register_ipykernel download_lulc lulc_rasters \
	execute_notebooks

#################################################################################
# COMMANDS                                                                      #
#################################################################################

# Set up python interpreter environment
## create conda environment
create_environment:
	conda env create -f environment.yml

## Register the environment as an IPython kernel for Jupyter
register_ipykernel:
	python -m ipykernel install --user --name pylandstats \
		--display-name "Python (pylandstats)"

# global variables/rules
DATA_DIR = data
DATA_RAW_DIR := $(DATA_DIR)/raw
DATA_PROCESSED_DIR := $(DATA_DIR)/processed
define MAKE_DATA_SUB_DIR
$(DATA_SUB_DIR): | $(DATA_DIR)
	mkdir $$@
endef
$(DATA_DIR):
	mkdir $@
$(foreach DATA_SUB_DIR, $(DATA_RAW_DIR) $(DATA_PROCESSED_DIR), \
	$(eval $(MAKE_DATA_SUB_DIR)))

NOTEBOOKS_DIR = notebooks
NOTEBOOK_OUTPUT_DIR := $(NOTEBOOKS_DIR)/output

$(NOTEBOOK_OUTPUT_DIR):
	mkdir $@

# land use/land cover data
LULC_URI = https://www.bfs.admin.ch/bfsstatic/dam/assets/6646411/master
LULC_DATA_DIR := $(DATA_RAW_DIR)/lulc
LULC_CSV_FILEPATH := $(LULC_DATA_DIR)/AREA_NOAS04_17_181029.csv

$(LULC_DATA_DIR): | $(DATA_RAW_DIR)
	mkdir $@
$(LULC_DATA_DIR)/%.zip: | $(LULC_DATA_DIR)
	curl $(LULC_URI) -o $@
$(LULC_DATA_DIR)/%.csv: $(LULC_DATA_DIR)/%.zip
	unzip -j $< '*.csv' -d $(LULC_DATA_DIR)
	touch $(LULC_CSV_FILEPATH)
download_lulc: $(LULC_CSV_FILEPATH)

LULC_COLUMNS := AS97R_4 AS09R_4 AS18_4
LULC_TIF_FILEPATH = $(DATA_PROCESSED_DIR)/veveyse-$(LULC_COLUMN).tif
LULC_TIF_FILEPATHS := $(foreach LULC_COLUMN, $(LULC_COLUMNS), \
	$(LULC_TIF_FILEPATH))
SLS_PREPROCESS_IPYNB := $(NOTEBOOKS_DIR)/A03-swisslandstats-preprocessing.ipynb

define MAKE_LULC_TIF
$(LULC_TIF_FILEPATH): $(LULC_CSV_FILEPATH) $(SLS_PREPROCESS_IPYNB) \
	| $(DATA_PROCESSED_DIR) $(NOTEBOOK_OUTPUT_DIR)
	papermill $(SLS_PREPROCESS_IPYNB) \
	        $(NOTEBOOK_OUTPUT_DIR)/$$(notdir $(SLS_PREPROCESS_IPYNB)) \
		-p lulc_csv_filepath $$< -p lulc_column $(LULC_COLUMN) \
		-p dst_filepath $$@
endef
$(foreach LULC_COLUMN, $(LULC_COLUMNS), $(eval $(MAKE_LULC_TIF)))
lulc_rasters: $(LULC_TIF_FILEPATHS)

$(NOTEBOOK_OUTPUT_DIR)/%.ipynb: $(NOTEBOOKS_DIR)/%.ipynb $(LULC_TIF_FILEPATHS) \
	| $(NOTEBOOK_OUTPUT_DIR)
	papermill $< $@ --cwd $(NOTEBOOKS_DIR)

NOTEBOOK_OUTPUT_IPYNB_FILEPATHS := $(foreach NOTEBOOK_IPYNB, \
	$(wildcard $(NOTEBOOKS_DIR)/*.ipynb), \
	$(NOTEBOOK_OUTPUT_DIR)/$(notdir $(NOTEBOOK_IPYNB)))
execute_notebooks: $(NOTEBOOK_OUTPUT_IPYNB_FILEPATHS)

.DEFAULT_GOAL := execute_notebooks

#################################################################################
# Self Documenting Commands                                                     #
#################################################################################

# Inspired by <http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html>
# sed script explained:
# /^##/:
# 	* save line in hold space
# 	* purge line
# 	* Loop:
# 		* append newline + line to hold space
# 		* go to next line
# 		* if line starts with doc comment, strip comment character off and loop
# 	* remove target prerequisites
# 	* append hold space (+ newline) to line
# 	* replace newline plus comments by `---`
# 	* print line
# Separate expressions are necessary because labels cannot be delimited by
# semicolon; see <http://stackoverflow.com/a/11799865/1968>
.PHONY: help
help:
	@echo "$$(tput bold)Available rules:$$(tput sgr0)"
	@echo
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| LC_ALL='C' sort --ignore-case \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=19 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' \
	| more $(shell test $(shell uname) = Darwin && echo '--no-init --raw-control-chars')
