library(Matrix)
library(Seurat)
library(ggplot2)
library(gridExtra)
options(bitmapType='cairo')

# Data processing commands for the expression matrix from Paulson Supplementary Data, updated to Seurat v3 syntax

raw_data <- read.csv('/mnt/park1/compbio/HLA/paulson_data/GSE118056_raw.expMatrix.csv', header = TRUE, row.names = 1)
data <- log2(1 + sweep(raw_data, 2, median(colSums(raw_data))/colSums(raw_data), '*')) # Normalization
cellTypes <- sapply(strsplit(colnames(data), ".", fixed=T), function(x) x[2])
cellTypes <- ifelse(cellTypes == '1', 'PBMC', 'Tumor')
seurat <- CreateSeuratObject(counts = data, project = '10x_MCC_2') # already normalized
seurat <- AddMetaData(object = seurat, metadata = apply(raw_data, 2, sum), col.name = 'nUMI_raw')
seurat <- AddMetaData(object = seurat, metadata = cellTypes, col.name = 'cellTypes')
seurat <- ScaleData(object = seurat, vars.to.regress = c('nUMI_raw'), model.use = 'linear', use.umi = FALSE)
seurat <- FindVariableFeatures(object = seurat, mean.function = ExpMean, dispersion.function = LogVMR, x.low.cutoff = 0.05, x.high.cutoff = 4, y.cutoff = 0.5)
seurat <- RunPCA(object = seurat, pc.genes = seurat@var.genes, pcs.compute = 40)
seurat <- RunTSNE(object = seurat, dims.use = 1:10, perplexity = 50, do.fast = TRUE)
seurat <- FindNeighbors(seurat, dims = 1:10, k.param = 20, reduction="pca")
seurat <- FindClusters(seurat, resolution = 0.6)

# Read in scHLAcount matrixes
mat1 <- readMM(file = paste0("/mnt/park1/compbio/HLA/only-count-true-ref/paulson-7692286", "/count_matrix.mtx"))
feature.names  <- read.delim(paste0("/mnt/park1/compbio/HLA/only-count-true-ref/paulson-7692286","/labels.tsv"), header = FALSE, stringsAsFactors = FALSE)
cell.names <- read.delim(gzfile(paste0("/mnt/park1/compbio/HLA/paulson_data/cellranger_outs/SRR7692286", "/outs/filtered_feature_bc_matrix/","barcodes.tsv.gz")), header = FALSE, stringsAsFactors = FALSE)
cell.names <- sapply(strsplit(cell.names$V1,"-",fixed=T), function(x) paste0(x[1], ".1"))
dimnames(mat1)[[1]] <- feature.names$V1
dimnames(mat1)[[2]] <- cell.names

mat2 <- readMM(file = paste0("/mnt/park1/compbio/HLA/only-count-true-ref/paulson-7692287", "/count_matrix.mtx"))
feature.names  <- read.delim(paste0("/mnt/park1/compbio/HLA/only-count-true-ref/paulson-7692287","/labels.tsv"), header = FALSE, stringsAsFactors = FALSE)
cell.names <- read.delim(gzfile(paste0("/mnt/park1/compbio/HLA/paulson_data/cellranger_outs/SRR7692287", "/outs/filtered_feature_bc_matrix/","barcodes.tsv.gz")), header = FALSE, stringsAsFactors = FALSE)
cell.names <- sapply(strsplit(cell.names$V1,"-",fixed=T), function(x) paste0(x[1], ".1"))
dimnames(mat2)[[1]] <- feature.names$V1
dimnames(mat2)[[2]] <- cell.names

# Tumor
mat3 <- readMM(file = paste0("/mnt/park1/compbio/HLA/only-count-true-ref/paulson-7692288", "/count_matrix.mtx"))
feature.names  <- read.delim(paste0("/mnt/park1/compbio/HLA/only-count-true-ref/paulson-7692288","/labels.tsv"), header = FALSE, stringsAsFactors = FALSE)
cell.names <- read.delim(gzfile(paste0("/mnt/park1/compbio/HLA/paulson_data/cellranger_outs/SRR7692288", "/outs/filtered_feature_bc_matrix/","barcodes.tsv.gz")), header = FALSE, stringsAsFactors = FALSE)
cell.names <- sapply(strsplit(cell.names$V1,"-",fixed=T), function(x) paste0(x[1], ".2"))
dimnames(mat3)[[1]] <- feature.names$V1
dimnames(mat3)[[2]] <- cell.names

mat4 <- readMM(file = paste0("/mnt/park1/compbio/HLA/only-count-true-ref/paulson-7692289", "/count_matrix.mtx"))
feature.names  <- read.delim(paste0("/mnt/park1/compbio/HLA/only-count-true-ref/paulson-7692289","/labels.tsv"), header = FALSE, stringsAsFactors = FALSE)
cell.names <- read.delim(gzfile(paste0("/mnt/park1/compbio/HLA/paulson_data/cellranger_outs/SRR7692289", "/outs/filtered_feature_bc_matrix/","barcodes.tsv.gz")), header = FALSE, stringsAsFactors = FALSE)
cell.names <- sapply(strsplit(cell.names$V1,"-",fixed=T), function(x) paste0(x[1], ".2"))
dimnames(mat4)[[1]] <- feature.names$V1
dimnames(mat4)[[2]] <- cell.names

mat <- cbind(mat1,mat2,mat3,mat4)

# Normalize counts and insert into matrix as metadata columns
c <- median(seurat$nCount_RNA)
curr_gene <- ""
gene_names <- c()
has_two_alleles <- c()
n_seen = 1

for (i in seq(1,length(feature.names$V1))) {
  f <- feature.names$V1[i]
  s <- strsplit(f, "*", fixed=T)
  if (s[[1]][1] == curr_gene) {
    n_seen <- n_seen + 1
  } else {
    if (n_seen == 1 && curr_gene != "") {
      #one allele
      gene_names <- c(gene_names, curr_gene)
      seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"sum"),metadata=mat[i-1,])
      seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"sum"),metadata=log2(1 + c*seurat@meta.data[paste0("gene",curr_gene,"sum")]/seurat$nCount_RNA))
    } else if (n_seen == 3) {
      #two alleles
      gene_names <- c(gene_names, curr_gene)
      has_two_alleles <- c(has_two_alleles, curr_gene)
      seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"sum"),metadata=mat[i-1,]+mat[i-2,]+mat[i-3,])
      seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene),metadata=mat[i-1,])
      seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"allele1"),metadata=mat[i-3,])
      seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"allele2"),metadata=mat[i-2,])
      
      seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"sum"),metadata=log2(1 + c*seurat@meta.data[paste0("gene",curr_gene,"sum")]/seurat$nCount_RNA))
      seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"sumnolog"),metadata=c*seurat@meta.data[paste0("gene",curr_gene,"sum")]/seurat$nCount_RNA)
      seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene),metadata=c*seurat@meta.data[paste0("gene",curr_gene)]/seurat$nCount_RNA)
      seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"allele1"),metadata=c*seurat@meta.data[paste0("gene",curr_gene,"allele1")]/seurat$nCount_RNA)
      seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"allele2"),metadata=c*seurat@meta.data[paste0("gene",curr_gene,"allele2")]/seurat$nCount_RNA)
      x <- paste0("gene",curr_gene,"allele1")
      y <- paste0("gene",curr_gene,"allele2")
      seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"ratio"),metadata=seurat@meta.data[x]/(seurat@meta.data[x]+seurat@meta.data[y]))
      n_seen = 1
    }
    curr_gene <- s[[1]][1]
  }
}
i <- i+1
if (n_seen == 1 && curr_gene != "") {
  #one allele
  gene_names <- c(gene_names, curr_gene)
  seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"sum"),metadata=mat[i-1,])
  seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"sum"),metadata=log2(1 + c*seurat@meta.data[paste0("gene",curr_gene,"sum")]/seurat$nCount_RNA))
} else if (n_seen == 3) {
  #two alleles
  gene_names <- c(gene_names, curr_gene)
  has_two_alleles <- c(has_two_alleles, curr_gene)
  seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"sum"),metadata=mat[i-1,]+mat[i-2,]+mat[i-3,])
  seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene),metadata=mat[i-1,])
  seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"allele1"),metadata=mat[i-3,])
  seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"allele2"),metadata=mat[i-2,])
  
  seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"sum"),metadata=log2(1 + c*seurat@meta.data[paste0("gene",curr_gene,"sum")]/seurat$nCount_RNA))
  seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"sumnolog"),metadata=c*seurat@meta.data[paste0("gene",curr_gene,"sum")]/seurat$nCount_RNA)
  seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene),metadata=c*seurat@meta.data[paste0("gene",curr_gene)]/seurat$nCount_RNA)
  seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"allele1"),metadata=c*seurat@meta.data[paste0("gene",curr_gene,"allele1")]/seurat$nCount_RNA)
  seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"allele2"),metadata=c*seurat@meta.data[paste0("gene",curr_gene,"allele2")]/seurat$nCount_RNA)
  x <- paste0("gene",curr_gene,"allele1")
  y <- paste0("gene",curr_gene,"allele2")
  seurat <- AddMetaData(object=seurat,col.name=paste0("gene",curr_gene,"ratio"),metadata=seurat@meta.data[x]/(seurat@meta.data[x]+seurat@meta.data[y]))
}

# Clusters determined by marker genes
tumorClusters <- c(2,3,4,6,7,10,11)
tumorCells <- seurat@meta.data["seurat_clusters"][,1] %in% tumorClusters
normalCells <- !tumorCells 

cellTypes1 <- ifelse(tumorCells, 'Tumor', 'Non-Tumor')
seurat <- AddMetaData(object = seurat, metadata = cellTypes1, col.name = 'cellTypes1')

# Load completed analysis up to this point
#save(seurat, file="/mnt/park1/compbio/HLA/paulson_robj/paulson_val_seurat.Rdata")
load("/mnt/park1/compbio/HLA/paulson_robj/paulson_val_seurat.Rdata")

# Plots

CELLTYPEPLOT <- TSNEPlot(seurat, group.by = 'cellTypes1') + ggtitle("Cell types inferred from marker genes") + theme(legend.position = c(0,0.1))
ggsave("figureS1.pdf", CELLTYPEPLOT, width=5, height=5, units="in")

a_plt <- FeaturePlot(seurat, paste0("gene","A", "sum"), reduction="tsne") + ggtitle("(a) HLA-A normalized expression") + theme(plot.title = element_text(size=12))
c_plt <- FeaturePlot(seurat, paste0("gene","B", "sum"), reduction="tsne") + ggtitle("(c) HLA-B normalized expression") + theme(plot.title = element_text(size=12))
e_plt <- FeaturePlot(seurat, paste0("gene","C", "sum"), reduction="tsne") + ggtitle("(e) HLA-C normalized expression") + theme(plot.title = element_text(size=12))

# Bug in Seurat related to plotting, fails when a NA is first: https://github.com/satijalab/seurat/issues/1853
# Temporary fix: reordering the rows so a NA doesn't come first
new.cell.order <- rownames(seurat@meta.data)[order(seurat@meta.data[paste0("gene","A","ratio")])]
b_plt <- FeaturePlot(seurat, paste0("gene","A", "ratio"), reduction="tsne", cols=c('blue','red'), cells=new.cell.order) + ggtitle("(b) Fraction of molecules assigned to allele A*02:01") + theme(plot.title = element_text(size=12))
d_plt <- FeaturePlot(seurat, paste0("gene","B", "ratio"), reduction="tsne", cols=c('blue','red')) + ggtitle("(d) Fraction of molecules assigned to allele B*35:01") + theme(plot.title = element_text(size=12))
f_plt <- FeaturePlot(seurat, paste0("gene","C", "ratio"), reduction="tsne", cols=c('blue','red')) + ggtitle("(f) Fraction of molecules assigned to allele C1") + theme(plot.title = element_text(size=12))

COMBINED <- grid.arrange(a_plt, b_plt, c_plt, d_plt, e_plt, f_plt,
                         layout_matrix=rbind(c(1,2),c(3,4),c(5,6)))
ggsave("figure3.pdf", COMBINED, width=8.5, height=10, units="in")

CELLTYPEPLOT <- TSNEPlot(seurat, group.by = 'cellTypes1') + ggtitle("(g) Cell types") + theme(plot.title = element_text(size=12)) + theme(axis.text.x=element_blank(),axis.ticks.x=element_blank(),axis.text.y=element_blank(),axis.ticks.y=element_blank(),axis.title=element_text(size=10))

a_plt <- FeaturePlot(seurat, paste0("gene","A", "sum"), reduction="tsne") + ggtitle("(a) HLA-A") + theme(plot.title = element_text(size=12)) + theme(legend.position = "none") + theme(axis.text.x=element_blank(),axis.ticks.x=element_blank(),axis.text.y=element_blank(),axis.ticks.y=element_blank(),axis.title=element_text(size=10))
b_plt <- FeaturePlot(seurat, paste0("gene","B", "sum"), reduction="tsne") + ggtitle("(b) HLA-B") + theme(plot.title = element_text(size=12)) + theme(legend.position = "none") + theme(axis.text.x=element_blank(),axis.ticks.x=element_blank(),axis.text.y=element_blank(),axis.ticks.y=element_blank(),axis.title=element_text(size=10))
c_plt <- FeaturePlot(seurat, paste0("gene","C", "sum"), reduction="tsne") + ggtitle("(c) HLA-C") + theme(plot.title = element_text(size=12)) + theme(axis.text.x=element_blank(),axis.ticks.x=element_blank(),axis.text.y=element_blank(),axis.ticks.y=element_blank(),axis.title=element_text(size=10))

# Bug in Seurat related to plotting, fails when a NA is first: https://github.com/satijalab/seurat/issues/1853
# Temporary fix: reordering the rows so a NA doesn't come first
new.cell.order <- rownames(seurat@meta.data)[order(seurat@meta.data[paste0("gene","A","ratio")])]
d_plt <- FeaturePlot(seurat, paste0("gene","A", "ratio"), reduction="tsne", cols=c('blue','red'), cells=new.cell.order) + ggtitle("(d) Fraction molecules\nA*02:01") + theme(plot.title = element_text(size=12)) + theme(legend.position = "none") + theme(axis.text.x=element_blank(),axis.ticks.x=element_blank(),axis.text.y=element_blank(),axis.ticks.y=element_blank(),axis.title=element_text(size=10))
e_plt <- FeaturePlot(seurat, paste0("gene","B", "ratio"), reduction="tsne", cols=c('blue','red')) + ggtitle("(e) Fraction molecules\nB*35:01") + theme(plot.title = element_text(size=12)) + theme(legend.position = "none") + theme(axis.text.x=element_blank(),axis.ticks.x=element_blank(),axis.text.y=element_blank(),axis.ticks.y=element_blank(),axis.title=element_text(size=10))
f_plt <- FeaturePlot(seurat, paste0("gene","C", "ratio"), reduction="tsne", cols=c('blue','red')) + ggtitle("(f) Fraction molecules C1") + theme(plot.title = element_text(size=12)) + theme(axis.text.x=element_blank(),axis.ticks.x=element_blank(),axis.text.y=element_blank(),axis.ticks.y=element_blank(),axis.title=element_text(size=10))

COMBINED <- grid.arrange(a_plt, b_plt, c_plt, d_plt, e_plt, f_plt, CELLTYPEPLOT,
                         layout_matrix=rbind(c(1,1,1,2,2,2,3,3,3,3),c(4,4,4,5,5,5,6,6,6,6),c(7,7,7,7,7,NA,NA,NA,NA,NA)))
ggsave("figure3-newlayout.pdf", COMBINED, width=8.5, height=8, units="in")



# Table 8
n_tumor <- sum(seurat$cellTypes1 == "Tumor")
mean(na.omit(seurat$geneAsumnolog[seurat$cellTypes1 == "Tumor"]))
mean(na.omit(seurat$geneBsumnolog[seurat$cellTypes1 == "Tumor"]))
mean(na.omit(seurat$geneCsumnolog[seurat$cellTypes1 == "Tumor"]))
mean(na.omit(seurat$geneAratio[seurat$cellTypes1 == "Tumor"]))*100
mean(na.omit(seurat$geneBratio[seurat$cellTypes1 == "Tumor"]))*100
mean(na.omit(seurat$geneCratio[seurat$cellTypes1 == "Tumor"]))*100

n_normal <- sum(seurat$cellTypes1 == "Non-Tumor")
mean(na.omit(seurat$geneAsumnolog[seurat$cellTypes1 == "Non-Tumor"]))
mean(na.omit(seurat$geneBsumnolog[seurat$cellTypes1 == "Non-Tumor"]))
mean(na.omit(seurat$geneCsumnolog[seurat$cellTypes1 == "Non-Tumor"]))
mean(na.omit(seurat$geneAratio[seurat$cellTypes1 == "Non-Tumor"]))*100
mean(na.omit(seurat$geneBratio[seurat$cellTypes1 == "Non-Tumor"]))*100
mean(na.omit(seurat$geneCratio[seurat$cellTypes1 == "Non-Tumor"]))*100


# Table 7 (Discovery Subject)

# Load completed analysis, same preprocessing steps as for Validation Subject
# save(PBMC, file="/mnt/park1/compbio/HLA/paulson_robj/paulson_disc_pbmc.Rdata")
# save(tumor, file="/mnt/park1/compbio/HLA/paulson_robj/paulson_disc_tumor.Rdata")
load("/mnt/park1/compbio/HLA/paulson_robj/paulson_disc_tumor.Rdata")
load("/mnt/park1/compbio/HLA/paulson_robj/paulson_disc_pbmc.Rdata")

n_tumor <- sum(tumor$cellTypes1 == "Tumor")
mean(na.omit(tumor$geneAsumnolog[tumor$cellTypes1 == "Tumor"]))
mean(na.omit(tumor$geneBsumnolog[tumor$cellTypes1 == "Tumor"]))
mean(na.omit(tumor$geneCsumnolog[tumor$cellTypes1 == "Tumor"]))
mean(na.omit(tumor$geneAratio[tumor$cellTypes1 == "Tumor"]))*100
mean(na.omit(tumor$geneBratio[tumor$cellTypes1 == "Tumor"]))*100
mean(na.omit(tumor$geneCratio[tumor$cellTypes1 == "Tumor"]))*100

n_normal <- sum(tumor$cellTypes1 == "Non-Tumor")
mean(na.omit(tumor$geneAsumnolog[tumor$cellTypes1 == "Non-Tumor"]))
mean(na.omit(tumor$geneBsumnolog[tumor$cellTypes1 == "Non-Tumor"]))
mean(na.omit(tumor$geneCsumnolog[tumor$cellTypes1 == "Non-Tumor"]))
mean(na.omit(tumor$geneAratio[tumor$cellTypes1 == "Non-Tumor"]))*100
mean(na.omit(tumor$geneBratio[tumor$cellTypes1 == "Non-Tumor"]))*100
mean(na.omit(tumor$geneCratio[tumor$cellTypes1 == "Non-Tumor"]))*100

n_normal <- length(PBMC$TimePoints)
mean(na.omit(PBMC$geneAsumnolog))
mean(na.omit(PBMC$geneBsumnolog))
mean(na.omit(PBMC$geneCsumnolog))
mean(na.omit(PBMC$geneAratio))*100
mean(na.omit(PBMC$geneBratio))*100
mean(na.omit(PBMC$geneCratio))*100
