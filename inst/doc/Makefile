# documentation requiring compilation into a presentation view:
#
# create the data item modelLotekTagLifeSpan.rda and the .pdf
# from modelLotekTagLifeSpan.Rmd
#

all: motus_data_overview.pdf modelLotekTagLifeSpan.pdf modelLotekTagLifeSpan.rda tags_view_graph.pdf data_flow.pdf sensorgnome_data_flow.pdf

%.pdf %.rda: %.Rmd lotekTagLifespanByBatteryAndBI.csv
	Rscript -e "library(rmarkdown);render(commandArgs(TRUE)[1])" $<

%.pdf %.svg: %.dot
	dot -Tpdf $< -o $@
	dot -Tsvg $< -o $(subst pdf,svg,$@)

%.pdf: %.md
	pandoc -o $@ $<
