# This code Runs conStruct on sites. Some parts are quite slow to run but if running in rstudio it will sow you a progress in percentage.
# It reqires that you have already loaded in your dart file, filtered and combined with the meta. It also like the file format usually used for RnR.
# most of the information can be found in the conStruct Git here: https://github.com/gbradburd/conStruct/tree/master/vignettes


library(conStruct)

# RRtools-esque function to format data
dart2conStruct <- function(dms, basedir, species, dataset, pop) {
  
  # Step 1, get the genotypes ready
  treatment <- dms$treatment 
  if (dms$encoding == "altcount") {
    cat(" Dart data object for ", dataset, "in species", species, "\n")
    cat(" Dart data object found with altcount genotype encoding. Commencing conversion to genind. \n")
  } else {
    cat(" Fatal Error: The dart data object does not appear to have altcount genotype encoding. \n"); stop()
  }
  
  # Population allele stats
  population_allele_stats  <- calculate.population.allele.stats(dms, pop)
  population_spatial_dist  <- population.pw.spatial.dist(dms, pop)
  
  ind_NA_loci <- which( colSums(is.na(population_allele_stats$count)) > 0 )
  if ( length(ind_NA_loci) > 0 ) {
    cat("found ",  length(ind_NA_loci), "loci with no data for a population. Removing these loci \n")
    population_allele_stats$minor  <- population_allele_stats$minor[,-ind_NA_loci]
    population_allele_stats$count  <- population_allele_stats$count[,-ind_NA_loci]
    population_allele_stats$sample <- population_allele_stats$sample[,-ind_NA_loci]
    population_allele_stats$freq   <- population_allele_stats$freq[,-ind_NA_loci]
  }
  
  # make directory, write files 
  dir <- paste(basedir, species, "/popgen",sep="")
  if(!dir.exists(dir)) {
    cat("  Directory: ", dir, " does not exist and is being created. \n")
    dir.create(dir)
  } else {
    cat("  Directory: ", dir, " already exists... content might be overwritten. \n")
  }
  
  dir <- paste(basedir, species, "/popgen/",treatment,sep="")
  
  if(!dir.exists(dir)) {
    cat("  Directory: ", dir, " does not exist and is being created. \n")
    dir.create(dir)
  } else {
    cat("  Directory: ", dir, " already exists...  \n")
  }
  
  cs_dir    <- paste(basedir,species,"/popgen/",treatment,"/conStruct", sep="")
  
  if(!dir.exists(cs_dir)) {
    cat("  conStruc directory: ", cs_dir, " does not exist and is being created. \n")
    dir.create(cs_dir)
  } else {
    cat("  conStruc directory: ", cs_dir, " already exists, content will be overwritten. \n")
  }
  
  cs_object_file   <- paste(cs_dir,"/",species,"_",dataset,".rda",sep="")
  
  
  counts       <- population_allele_stats$minor
  sample_sizes <- population_allele_stats$sample
  lon_lat  <- population_spatial_dist$pop_info$lon_lat
  freq <- counts/sample_sizes
  prefix       <- paste(species, "_",dataset,sep="")
  
  require(geosphere)
  n <- nrow(lon_lat)
  s <- mat.or.vec(n, n)
  
  for (a in 1:n){
    lla <- c(lon_lat[a, 1], lon_lat[a, 2])
    for (b in 1:n){
      llb <- c(lon_lat[b, 1], lon_lat[b, 2])
      d <- distCosine(lla, llb)
      s[a, b] <- d
    }
  }
  
  cs <- list(counts=counts, sample_sizes=sample_sizes, lon_lat=lon_lat, freq=freq, dist=s, cs_dir=cs_dir, prefix=prefix)
  save(cs, file=cs_object_file)
  
  return(cs)
  
}


# example
CS <- dart2conStruct(dmv3, basedir, species, dataset,  dmv3$meta$analyses$Sna)



# multiple runs loop with spatial distance
for (k in 1:6){
  con <- conStruct(spatial= TRUE, K=k, freqs = CS$freq, geoDist = CS$dist, coords = CS$lon_lat, prefix = paste0("output/",CS$prefix,"_TRUE_K",k))
}
# multiple runs loop without spatial distance
for (k in 1:6){
  con <- conStruct(spatial= FALSE, K=k, freqs = CS$freq, geoDist = CS$dist, coords = CS$lon_lat, prefix = paste0("output/",CS$prefix,"_FALSE_K",k))
}





# Loop through output files generated by conStruct and calculate/plot layer contributions.
# geo="FALSE" geo distance or not.
# num_runs=6  number of runs

lc.calculations <- function (geo, num_runs){
  nm = num_runs
  nma = nm-1
  # Build data format
  K=1
  # load the conStruct.results.Robj and data.block.Robj from files saved at the end of a conStruct run
  layer.contributions <- matrix(NA,nrow=nm,ncol=nm)
  load(paste0("output/",CS$prefix,"_",geo,"_K",K,"_conStruct.results.Robj"))
  load(paste0("output/",CS$prefix,"_",geo,"_K",K,"_data.block.Robj"))
  # calculate layer contributions
  layer.contributions[,1] <- c(calculate.layer.contribution(conStruct.results[[1]],data.block),rep(0,nma))
  tmp <- conStruct.results[[1]]$MAP$admix.proportions
  
  # Loop thorugh other runs
  for (k in 2:nm){
    load(paste0("output/",CS$prefix,"_",geo,"_K",k,"_conStruct.results.Robj"))
    load(paste0("output/",CS$prefix,"_",geo,"_K",k,"_data.block.Robj"))
    # match layers up across runs to keep plotting colors consistent
    tmp.order <- match.layers.x.runs(tmp,conStruct.results[[1]]$MAP$admix.proportions)
    # calculate layer contributions
    layer.contributions[,k] <- c(calculate.layer.contribution(conStruct.results=conStruct.results[[1]],
                                                              data.block=data.block,
                                                              layer.order=tmp.order),
                                 rep(0,nm-k))
    tmp <- conStruct.results[[1]]$MAP$admix.proportions[,tmp.order]
  }
  row.names(layer.contributions) <- paste0("Layer_",1:nm)
  return(layer.contributions)
}

# Example
layer.contributions_FALSE <- lc.calculations(FALSE, 6)
layer.contributions_TRUE <- lc.calculations(TRUE, 6)

barplot(layer.contributions_TRUE,
        col=c("blue", "red", "goldenrod1", "forestgreen", "darkorchid1", "grey"),
        xlab="",
        ylab="layer contributions_TRUE",
        names.arg=paste0("K=",1:6))

barplot(layer.contributions_FALSE,
        col=c("blue", "red", "goldenrod1", "forestgreen", "darkorchid1", "grey"),
        xlab="",
        ylab="layer contributions_FALSE",
        names.arg=paste0("K=",1:6))



# Cross validation analysis.
# this takes a while to run, it is essentially running each run multiple times.
my.xvals <- x.validation(train.prop = 0.9,
                         n.reps = 3,
                         K = 1:6,
                         freqs = CS$freq,
                         data.partitions = NULL,
                         geoDist = CS$dist,
                         coords = CS$lon_lat,
                         prefix = paste0("output/cross_val/",CS$prefix),
                         n.iter = 1e3,
                         make.figs = FALSE,
                         save.files = FALSE)

sp.results <- as.matrix(
  read.table(paste0("output/cross_val/",CS$prefix,"_sp_xval_results.txt"),
             header = TRUE,
             stringsAsFactors = FALSE)
)
nsp.results <- as.matrix(
  read.table(paste0("output/cross_val/",CS$prefix,"_nsp_xval_results.txt"),
             header = TRUE,
             stringsAsFactors = FALSE)
)
# adding error bars
sp.CIs <- apply(sp.results,1,function(x){mean(x) + c(-1.96,1.96) * sd(x)/length(x)})
nsp.CIs <- apply(nsp.results,1,function(x){mean(x) + c(-1.96,1.96) * sd(x)/length(x)})

plot(rowMeans(sp.results),
     pch=19,col="blue",
     ylab="predictive accuracy",xlab="values of K",
     ylim=range(sp.results,nsp.results),
     main="cross-validation results")
points(rowMeans(nsp.results),col="green",pch=19)
segments(x0 = 1:nrow(sp.results),
         y0 = sp.CIs[1,],
         x1 = 1:nrow(sp.results),
         y1 = sp.CIs[2,],
         col = "blue",lwd=2)
segments(x0 = 1:nrow(nsp.results),
         y0 = nsp.CIs[1,],
         x1 = 1:nrow(nsp.results),
         y1 = nsp.CIs[2,],
         col = "green",lwd=2)




