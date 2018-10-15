#!/usr/bin/env Rscript 
#Creates a SingleCellExperiment object, which scater's calculateQCMetrics already applied

suppressPackageStartupMessages(require(optparse))
suppressPackageStartupMessages(require(workflowscriptscommon))
suppressPackageStartupMessages(require(SingleCellExperiment))
suppressPackageStartupMessages(require(scater))

# parse options
#SCE-specific options
option_list = list(
  make_option(
    c("-a", "--counts"),
    action = "store",
    default = NA,
    type = 'character',
    help = "Comma-separated list of file names specifying tsv-format matrices. All elements of the list must have the same dimensions, and dimension names (if present) must be consistent across elements and with the row names of rowRanges and colData. The first column of all files is assumed to be feature names."
  ),
  make_option(
    c("-n", "--assay-names"),
    action = "store",
    default = 'counts',
    type = 'character',
    help = "Comma-separated list of assay names. If this is not specified, and only a single assay is provided, this will be 'counts'. Otherwise assay names will be derived from input files"
  ),
  make_option(
    c("-r", "--row-data"),
    action = "store",
    default = NULL,
    type = 'character',
    help = "Path to TSV format file describing the features. Row names, if present, become the row names of the SingleCellExperiment."
  ),
  make_option(
    c("-c", "--col-data"),
    action = "store",
    default = NULL,
    type = 'character',
    help = "Path to TSV format file describing the samples. Row names, if present, become the column names of the SummarizedExperiment object. The number of rows of the DataFrame must equal the number of rows of the matrices in assays."
  ),
  make_option(
    c("-s", "--spike-names"),
    action = "store",
    default = NA,
    type = 'character',
    help = "Path to file containing spike names (column 1) and types (e.g. ERCC, column 2), in TSV format."
  ),
  #The scater-specific options
  make_option(
    c("-e", "--exprs-values"),
    action = "store",
    default = 'counts',
    type = 'character',
    help= "character(1), indicating slot of the 'assays' of the 'object' that should be used to define expression. Valid options are 'counts' [default; recommended],'tpm','fpkm' and 'logcounts', or anything else in the object added manually by the user."
  ),
  make_option(
    c("-f", "--mt-controls"),
    action = "store",
    default = NULL,
    type = 'character',
    help = "file containing a list of the control files with one file per line. Each control file should have one feature (e.g. gene) per line. A named list is created (names derived from control file names) containing one or more vectors to identify feature controls (for example, ERCC spike-in genes, mitochondrial genes, etc)"
  ),
  make_option(
    c("-p", "--ercc-controls"),
    action = "store",
    default = NULL,
    type = 'character',
    help = "file containing a list of the control files with one file per line. Each control file should have one feature (e.g. gene) per line. A named list is created (names derived from control file names) containing one or more vectors to identify feature controls (for example, ERCC spike-in genes, mitochondrial genes, etc)"
  ),
  make_option(
    c("-l", "--cell-controls"),
    action = "store",
    default = NULL,
    type = 'character',
    help = "file (one cell per line) to be used to derive a vector of cell (sample) names used to identify cell controls (for example, blank wells or bulk controls)."
  ),
  make_option(
    c("-o", "--output-object-file"),
    action = "store",
    default = NA,
    type = 'character',
    help = "File name in which to store serialized SingleCellExperiment object."
  )
)

opt <- wsc_parse_args(option_list, mandatory = c('counts', 'output_object_file'))

# Read the expression matrix

counts <- wsc_split_string(opt$counts)
reads <- read.table(counts)

# Read row and column annotations

rowdata <- opt$row_data

if ( ! is.null(opt$row_data) ){
  rowdata <- read.delim(opt$row_data)
}

coldata <- opt$col_data

if ( ! is.null(opt$col_data) ){
  coldata <- read.delim(opt$col_data)
}

# Now build the object

sce <- SingleCellExperiment( assays = list(counts = as.matrix(reads)), colData = coldata, rowData = rowdata)
# Define spikes (if supplied)

if ( ! is.na(opt$spike_names) ){
  
  if ( ! file.exists(opt$spike_names) ){
    stop(paste("Supplied spikes file", opt$spike_names, "does not exist"))
  }
  
  spike_names <- read.table(opt$spike_names)
  
  spikes_by_type <- split(spike_names, spike_names$V2)
  for ( st in names(spikes_by_type) ){
    isSpike(single_cell_experiment, st) <- match(spikes_by_type[[st]]$V1, rownames(single_cell_experiment))
  }
}

#Scater options

# Check feature_controls (only mitochondrial and ERCC used for now)

if (! is.null(opt$mt_controls) && opt$mt_controls != 'NULL'){
  if (! file.exists(opt$mt_controls)){
    stop((paste('Supplied feature_controls file', opt$mt_controls, 'does not exist')))
  }else{
    mt_controls <- readLines(opt$mt_controls)

  }
}else{
  mt_controls <- NULL
}

if (! is.null(opt$ercc_controls) && opt$ercc_controls != 'NULL'){
  if (! file.exists(opt$ercc_controls)){
    stop((paste('Supplied feature_controls file', opt$ercc_controls, 'does not exist')))
  }else{
    ercc_controls <- readLines(opt$ercc_controls)
    
  }
}else{
  ercc_controls <- NULL
}

# Check cell_controls
if (! is.null(opt$cell_controls) && opt$cell_controls != 'NULL'){
  if (! file.exists(opt$cell_controls)){
    stop((paste('Supplied feature_controls file', opt$cell_controls, 'does not exist')))
  }else{
    cell_controls <- readLines(opt$cell_controls)
  }
}else{
  cell_controls <- NULL
}


# calculate QCMs
sce  <- calculateQCMetrics(sce, exprs_values = opt$exprs_values, feature_controls = list(MT=mt_controls, ERCC=ercc_controls), cell_controls = list(empty = cell_controls))

# Output to a serialized R object
saveRDS(sce, file = opt$output_object_file)