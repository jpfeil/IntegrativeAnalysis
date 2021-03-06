# R source code
# Main function for integrative models allowing for CNV-methylation association

# Arguments to input in the function "Integrated_Original" :

# -Gene = the matrix of genes, number of columns = number of genes
# -methy = the matrix of methylation sites, number of columns = number of methylation sites
# -CNV = the matrix of CNVs, number of columns = number of CNVs
# -y = the matrix containing the survival time (y), the censoring indicator (Event), and other clinical variables
# -Gene_CNV = matrix of three columns. The first column contains the identifiers of CNVs, 
#the second column the gene to which the CNV maps, and the third column the associated
#functional network
# -Gene_Methy has the same format as Gene_CNV expect that the first column contains
#the identifiers for methylations sites
# -Gene_Pathway = matrix of two columns. First column contains the gene identifiers and
#the second column gives the associated functional network
# -multi_methy = TRUE means that a multivariate model is used for the association between 
#methylation sites and CNVs if FALSE univariate models are fitted
# -intra = TRUE means that an Integrative-gene scenario is considered
# -pathway = TRUE means that an Integrative-network scenario is considered
# -nfolds = number of folds used in the cross-validation procedure of the glmnet function, which is called in  
#the function "regression" defined in UtilFunctions.R
# -alpha = penalty used in the glmnet function, alpha = 1 corresponds to the lasso penalty

# Output of function:

# -R2.adj = vector of adjusted-R2 value corresponding to four different models:
#"Age model", "Reference model", "Integrative model" allowing direct CNV-survival association, and  
#"Integrative model" not allowing direct CNV-survival association, respectively
# -cIndex  = vector of c-index values corresponding to four different models:
#"Age model", "Reference model", "Integrative model" allowing direct CNV-survival association, and  
#"Integrative model" not allowing direct CNV-survival association, respectively
# -coef = vector of regression coefficients for selected markers in the "Integrative model" allowing direct CNV-survival association
# -coef.2 = vector of regression coefficients for selected markers in the "Integrative model" not allowing direct CNV-survival association
# -coef.4 = vector of regression coefficients for selected markers in "Reference model"

 Integrated_Original <- function(Gene,methy, CNV, y, Gene_CNV, Gene_Methy, Gene_Pathway,
                                multi_methy= FALSE, intra =TRUE, pathway=FALSE,
                                nfolds=10, alpha =1)
{
  
  n = nrow(y) 
  
  geneWithBoth = colnames(Gene)[which(colnames(Gene)
  		%in%intersect(colnames(Gene),intersect(Gene_Methy[,2],Gene_CNV[,2])))]
  geneWithCNV = colnames(Gene)[which(colnames(Gene)
  		%in%intersect(colnames(Gene),Gene_CNV[,2]))]
  geneWithCNV = geneWithCNV[-which(geneWithCNV
  		%in%intersect(geneWithBoth,geneWithCNV))]

  geneWithMethy = colnames(Gene)[which(colnames(Gene)
  		%in%intersect(colnames(Gene),Gene_Methy[,2]))]
  geneWithMethy = geneWithMethy[-which(geneWithMethy
  		%in%intersect(geneWithBoth,geneWithMethy))]
  
  geneWithout = (1:ncol(Gene))[-which(colnames(Gene)
  		%in%c(geneWithBoth,geneWithCNV,geneWithMethy))]

  RNA_modulated_methy_CNV =list() 
  RNA_modulated_methy_other= list() 
  RNA_modulated_CNV= list() 
  RNA_modulated_other= list()
  
######################################################################
##########  1. Analysis for genes with methylation and CNV data
######################################################################  
  resMethy = list()
  for( g in geneWithBoth){
    sub_CNV = which(Gene_CNV[,2] == g) 
    sub_methy = which(Gene_Methy[,2] == g)
    x_tmp = as.matrix(CNV[,sub_CNV])
    colnames(x_tmp) = colnames(CNV)[sub_CNV]
    y_tmp = as.matrix(methy[,sub_methy])
    colnames(y_tmp) = colnames(methy)[sub_methy]

    if (multi_methy){
      if ((ncol(y_tmp) > 1) & (ncol(x_tmp) > 1)){
        tmp = regression(x = x_tmp, y = y_tmp, alpha=1, nfolds=nfolds)
      }else{ 
        if ((ncol(y_tmp) > 1) & (ncol(x_tmp) == 1)){
          tmp = regression(x = cbind(x_tmp,0), y = y_tmp, alpha=1, nfolds=nfolds)
        }else{
          tmp = apply(y_tmp, 2, function(l) { regression(x = x_tmp, y = as.matrix(l), 
          	alpha=1, nfolds=nfolds)})
        }
      }
    }else{
      tmp = apply(y_tmp, 2, function(l) {
        regression(x = x_tmp, y = as.matrix(l), alpha=1, nfolds=nfolds)
      })
    }
    names(tmp) = colnames(methy)[sub_methy]
    resMethy = c(resMethy,tmp)
  }
  
  
  methy_modulated_CNV = lapply(resMethy,function(y){
    ind1 = y$active_index
    ind = which(colnames(CNV)%in%names(ind1))
    if ((length(ind)!=1)& (length(ind)!=0)){lol= CNV[,ind]%*%(y$active)}
    if (length(ind)==1){lol= CNV[,ind]*y$active}
    if (length(ind)==0){lol= as.matrix(CNV[,3]*0)}
    return(lol)})
  
  X1 = matrix(unlist(methy_modulated_CNV),ncol=length(methy_modulated_CNV),byrow=FALSE)
  colnames(X1) = paste(names(resMethy),"CNV",sep="_")
  methy_modulated_other = list()
  
  for (i in 1:length(resMethy)){
    ind = which(colnames(methy)%in%names(resMethy)[i])
    methy_modulated_other[[i]]= methy[,ind] - methy_modulated_CNV[[i]] - 
    	resMethy[[i]]$inter
  }
  
  X2 =  matrix(unlist(methy_modulated_other),ncol=length(methy_modulated_CNV),byrow=FALSE)
  colnames(X2) = paste(names(resMethy),"other",sep="_")
  
  indCNV_methy = lapply(resMethy,function(y){names(y$active_index)}) 
  ##All CNV selected to explain methylation
  indCNV_methy = sort(unique(unlist(indCNV_methy)))
  indCNV_methy = which(colnames(CNV)%in% indCNV_methy)
  resCNVselectedMethy = indCNV_methy
  resCNVNoSelectedMethy = (1:ncol(CNV))[-indCNV_methy]
  CNVgene = as.matrix(CNV[,resCNVNoSelectedMethy])

  
  res3 =list()
  for( g in geneWithBoth){
    if (intra) {sub_CNV = as.character(Gene_CNV[Gene_CNV[,2] == g,1] )
    }else{ 
      if (pathway){
        path = Gene_Pathway[which(Gene_Pathway[,1]%in%g),2]
        gene_in_path = as.character(Gene_Pathway[which(Gene_Pathway[,2]%in%path),1])
        sub_CNV = as.character(Gene_CNV[which(Gene_CNV[,2]%in%gene_in_path),1])
      }else{      
        sub_CNV = colnames(CNVgene)
      }
    }   
    ind_CNV =  which(colnames(CNVgene)%in%sub_CNV)
    if (length(ind_CNV)!=0){ 
      part_CNV = as.matrix(CNVgene[,ind_CNV])
      colnames(part_CNV) = colnames(CNVgene)[ind_CNV]
      X = part_CNV
    }else{
      X = NULL
    }
    
    sub_methy = as.character(Gene_Methy[Gene_Methy[,2] == g,1] )
    ind_methy =  which(substring(colnames(X1),1,10)%in%sub_methy)
    if (length(ind_methy)!=0){ 
      part_methy_CNV = as.matrix(X1[,ind_methy])
      part_methy_O = as.matrix(X2[,ind_methy])
      colnames(part_methy_CNV) = colnames(X1)[ind_methy]
      colnames(part_methy_O) = colnames(X2)[ind_methy]
      X= cbind(part_methy_CNV,part_methy_O,X)
    }
    
    ind_methy_CNV = which(colnames(X)%in%colnames(X1))
    ind_methy_O = which(colnames(X)%in%colnames(X2))
    if (length(ind_CNV)!=0){ind_CNV= which(colnames(X)%in%colnames(part_CNV))
    }else{
      ind_CNV = NULL
    }
    y_tmp = as.matrix(Gene[,g])
    colnames(y_tmp) = g
    res3[[g]] = regression(x=X,y=y_tmp,alpha=1, nfolds =nfolds)
        
    select = res3[[g]]$active_index     
    ind = which(colnames(part_methy_CNV)%in%names(select))
    ind_tmp =  which(names(select)%in%colnames(part_methy_CNV))
    if ((length(ind)!=1)&(length(select)!=0))
    	{lol= part_methy_CNV[,ind]%*%(res3[[g]]$active[ind_tmp])}
    if (length(ind)==1){lol= part_methy_CNV[,ind]*res3[[g]]$active[ind_tmp]}
    if (length(ind)==0){lol = as.matrix(X1[,1]*0)}
    RNA_modulated_methy_CNV[[g]] = lol 
    

    ind = which(colnames(part_methy_O)%in%names(select))
    ind_tmp =  which(names(select)%in%colnames(part_methy_O))
    if ((length(ind)!=1)&(length(ind)!=0))
    	{lol= part_methy_O[,ind]%*%(res3[[g]]$active[ind_tmp])}
    if (length(ind)==1){lol= part_methy_O[,ind]*res3[[g]]$active[ind_tmp]}
    if (length(ind)==0){lol =  as.matrix(X2[,1]*c(0))}
    RNA_modulated_methy_other[[g]] =lol 

    if (!is.null(ind_CNV)){
      ind = which(colnames(part_CNV)%in%names(select))
      ind_tmp =  which(names(select)%in%colnames(part_CNV))
      if ((length(ind)!=1)&(length(ind)!=0))
      	{lol= part_CNV[,ind]%*%(res3[[g]]$active[ind_tmp])}
      if (length(ind)==1){lol= part_CNV[,ind]*res3[[g]]$active[ind_tmp]}
      if (length(ind)==0){lol =  as.matrix(CNVgene[,1]*c(0))}
      RNA_modulated_CNV[[g]] = lol
    }else{
      RNA_modulated_CNV[[g]] = as.matrix(CNVgene[,1]*c(0))
    }    
    RNA_modulated_other[[g]]= Gene[,g]-RNA_modulated_methy_CNV[[g]]-
      RNA_modulated_methy_other[[g]]-RNA_modulated_CNV[[g]]-res3[[g]]$inter
  }
  

  A1 = matrix(unlist(RNA_modulated_methy_CNV),
              ncol=length(RNA_modulated_methy_CNV),
              byrow=FALSE)
  colnames(A1) = paste(geneWithBoth,"methy_CNV",sep="_")

  A2 = matrix(unlist(RNA_modulated_methy_other),
              ncol=length(RNA_modulated_methy_other),
              byrow=FALSE)
  colnames(A2) = paste(geneWithBoth,"methy_other",sep="_")
  
  A3 = matrix(unlist(RNA_modulated_CNV),
              ncol=length(RNA_modulated_CNV),
              byrow=FALSE)  
  colnames(A3) = paste(geneWithBoth,"CNV",sep="_")

  A4 = matrix(unlist(RNA_modulated_other),
              ncol=length(RNA_modulated_other),
              byrow=FALSE)
  colnames(A4) = paste(geneWithBoth,"other",sep="_")

  
##############################################################
#########  2. Analysis for genes with methylation data   ##########
##############################################################
  
  RNA_modulated_CNV = list()
  RNA_modulated_methy = list()
  RNA_modulated_other =list() 
  resB=list()
  if (length(geneWithMethy)!=0){
    for( g in geneWithMethy){
      if (intra) {sub_CNV = as.character(Gene_CNV[Gene_CNV[,2] == g,1] )
      }else{ 
        if (pathway){
          path = Gene_Pathway[which(Gene_Pathway[,1]%in%g),2]
          gene_in_path = as.character(Gene_Pathway[which(Gene_Pathway[,2]%in%path),1])
          sub_CNV = as.character(Gene_CNV[which(Gene_CNV[,2]%in%gene_in_path),1])
        }else{      
          sub_CNV = colnames(CNVgene)}
      }
      ind_CNV =  which(colnames(CNVgene)%in%sub_CNV)
      if (length(ind_CNV)!=0){ 
        part_CNV = as.matrix(CNVgene[,ind_CNV])
        colnames(part_CNV) = colnames(CNVgene)[ind_CNV]
        X = part_CNV
      }else{
        X = NULL
      }
      
      sub_methy = as.character(Gene_Methy[Gene_Methy[,2] == g,1] )
      ind_methy =  which(colnames(methy)%in%sub_methy)
      part_methy = as.matrix(methy[,sub_methy])
      colnames(part_methy) = colnames(methy)[ind_methy]
      X= cbind(part_methy,X)
      
      y_tmp = as.matrix(Gene[,g])
      colnames(y_tmp) = g
      resB[[g]] = regression(x=X,y=y_tmp)
      
      select = resB[[g]]$active_index 
      
      ind = which(colnames(part_methy)%in%names(select))
      ind_tmp =  which(names(select)%in%colnames(part_methy))
      if ((length(ind)!=1)&(length(select)!=0))
      	{lol= part_methy[,ind]%*%(resB[[g]]$active[ind_tmp])}
      if (length(ind)==1){lol= part_methy[,ind]*resB[[g]]$active[ind_tmp]}
      if (length(ind)==0){lol = as.matrix(methy[,1]*0)}
      RNA_modulated_methy[[g]] = lol   
      
      #######Modulated by CNV
      if (length(ind_CNV)!=0){
        ind = which(colnames(part_CNV)%in%names(select))
        ind_tmp =  which(names(select)%in%colnames(part_CNV))
        if ((length(ind)!=1)&(length(select)!=0))
        		{lol= part_CNV[,ind]%*%(resB[[g]]$active[ind_tmp])}
        if (length(ind)==1){lol= part_CNV[,ind]*resB[[g]]$active[ind_tmp]}
        if (length(ind)==0){lol = as.matrix(CNV[,1]*0)}
        RNA_modulated_CNV[[g]] = lol  
      }else{
        RNA_modulated_CNV[[g]] = as.matrix(CNVgene[,1]*c(0))
      }
      
      RNA_modulated_other[[g]]= Gene[,g]-RNA_modulated_methy[[g]]-
        RNA_modulated_CNV[[g]]-resB[[g]]$inter
    }
    
    B1 = matrix(unlist(RNA_modulated_methy),ncol=length(RNA_modulated_methy),byrow=FALSE)
    colnames(B1) = paste(names(resB),"Methy",sep="_")
    
    B2 = matrix(unlist(RNA_modulated_CNV),ncol=length(RNA_modulated_CNV),byrow=FALSE)
    colnames(B2) = paste(names(resB),"CNV",sep="_")
    
    B3 =  matrix(unlist(RNA_modulated_other),ncol=length(RNA_modulated_other),byrow=FALSE)
    colnames(B3) = paste(names(resB),"other",sep="_")
  }else{
    B1 = rep(0,n)
    B2 = B1
    B3 = B1 
  }
  
############################################################
##########   3. Analysis for genes with CNV data   #####
############################################################  

  RNA_modulated_CNV = list()
  RNA_modulated_other = list()
  
  resC=list()
  if(length( c(geneWithCNV,colnames(Gene)[geneWithout])) == 0 ){
    C1 = rep(0,nrow(y))
    C2 = rep(0,nrow(y))
  }else{
    if (intra){
      for (g in geneWithCNV){
        sub_CNV = as.character(Gene_CNV[Gene_CNV[,2] == g,1] )
        ind_CNV =  which(colnames(CNVgene)%in%sub_CNV)
        if (length(ind_CNV)!=0){ 
          part_CNV = as.matrix(CNVgene[,ind_CNV])
          colnames(part_CNV) = colnames(CNVgene)[ind_CNV]
          X = part_CNV
          y_tmp = as.matrix(Gene[,g])
          colnames(y_tmp) = g
          resC[[g]] = regression(x=X,y=y_tmp,alpha =1 ,nfolds= nfolds)
          select = resC[[g]]$active_index 
          ##gives us all variables selected to explain the gene expression
          ind = which(colnames(part_CNV)%in%names(select))
          ind_tmp =  which(names(select)%in%colnames(part_CNV))
          if ((length(ind)!=1)&(length(select)!=0))
          	{lol= part_CNV[,ind]%*%(resC[[g]]$active[ind_tmp])}
          if (length(ind)==1){lol= part_CNV[,ind]*resC[[g]]$active[ind_tmp]}
          if (length(ind)==0){lol = as.matrix(methy[,1]*0)}
          RNA_modulated_CNV[[g]] = lol             
        }else{
          RNA_modulated_CNV[[g]] = as.matrix(methy[,1]*0)
          resC[[g]]$inter = lm(Gene[,g] ~ 1)$coef[1]
        }
        RNA_modulated_other[[g]]= Gene[,g]-RNA_modulated_CNV[[g]]-resC[[g]]$inter
      }
    }else{
      for(g in c(geneWithCNV,colnames(Gene)[geneWithout])){        
        if (pathway){
          path = Gene_Pathway[which(Gene_Pathway[,1]%in%g),2]
          gene_in_path = as.character(Gene_Pathway[which(Gene_Pathway[,2]%in%path),1])
          sub_CNV = as.character(Gene_CNV[which(Gene_CNV[,2]%in%gene_in_path),1])
        }else{      
          sub_CNV = colnames(CNVgene)
        }
        ind_CNV = which(colnames(CNVgene)%in%sub_CNV)
        if (length(ind_CNV)!=0){ 
          part_CNV = as.matrix(CNVgene[,ind_CNV])
          colnames(part_CNV) = colnames(CNVgene)[ind_CNV]
          X = part_CNV
          y_tmp = as.matrix(Gene[,g])
          colnames(y_tmp) = g
          resC[[g]] = regression(x=X,y=y_tmp,alpha =1 ,nfolds= nfolds)
          select = resC[[g]]$active_index 
          ind = which(colnames(part_CNV)%in%names(select))
          ind_tmp =  which(names(select)%in%colnames(part_CNV))
          if ((length(ind)!=1)&(length(select)!=0))
          	{lol= part_CNV[,ind]%*%(resC[[g]]$active[ind_tmp])}
          if (length(ind)==1){lol= part_CNV[,ind]*resC[[g]]$active[ind_tmp]}
          if (length(ind)==0){lol = as.matrix(methy[,1]*0)}
          RNA_modulated_CNV[[g]] = lol             
        }else{
          RNA_modulated_CNV[[g]] = as.matrix(methy[,1]*0)
          resC[[g]]$inter = lm(Gene[,g]~1)$coef[1]
        }  
        RNA_modulated_other[[g]]= Gene[,g]-RNA_modulated_CNV[[g]]-resC[[g]]$inter
      }
    }
    C1 = matrix(unlist(RNA_modulated_CNV),ncol=length(RNA_modulated_CNV),byrow=FALSE)
    colnames(C1) = paste(names(resC),"CNV",sep="_")

    C2 =  matrix(unlist(RNA_modulated_other),ncol=length(RNA_modulated_other),byrow=FALSE)
    colnames(C2) = paste(names(resC),"other",sep="_")
  }
  
  
#########################################################
##########   4. Final analysis    ############################
#########################################################
  
  indCNV_RNA = unique(unlist(lapply(res3,function(y){names(y$active_index)})))
  indCNV_RNAbis = unique(unlist(lapply(resC,function(y){names(y$active_index)}),
  	lapply(resB,function(y){names(y$active_index)})))
  indCNV_y = sort(unique(c(indCNV_RNA,indCNV_RNAbis)))
  if(length(indCNV_y)!=0){ CNVy = CNVgene[,-which(colnames(CNVgene)%in%indCNV_y)]
  }else{
    CNVy =rep(0,n)
  }


  cIndex = rep(0,4)
  R2 = rep(0,4)
  R2.adj =rep(0,4) 

  res = coxph(Surv(y$y,y$Event)~ 1+y$Age)
  logNull = res$log[1]
  logAge = res$log[2]
  LLR_0 = -2*(logNull-logAge)
  cIndex[1] = summary(res)$concordance[1]
  R2[1] = 1-exp((-2/n)*(logAge-logNull))
  R2.adj[1] = 1-(1-R2[1])*(n-1)/(n-1-1) 
  if (intra){
      X = cbind(A1,A2,A3,A4,B1,B2,B3,C1,C2, CNVy)
      X = X[,which(apply(X,2,sum)!=0)]
      Xmeth1 = cbind(y$Age,X,Gene[,geneWithout])
      colnames(Xmeth1)[1] = c("Age")
      
      X.2 = cbind(A1,A2,A3,A4,B1,B2,B3,C1,C2)
      X.2 = X.2[,which(apply(X.2,2,sum)!=0)]
      X.meth.2 = cbind(y$Age,X.2,Gene[,geneWithout])
      colnames(X.meth.2)[1] = c("Age")
    }else{
      X = cbind(A1,A2,A3,A4,B1,B2,B3,C1,C2, CNVy)
      X = X[,which(apply(X,2,sum)!=0)]
      Xmeth1 = cbind(y$Age,X)
      colnames(Xmeth1)[1] = c("Age")
      
      X.2 = cbind(A1,A2,A3,A4,B1,B2,B3,C1,C2)
      X.2 = X.2[,which(apply(X.2,2,sum)!=0)]
      X.meth.2 = cbind(y$Age,X.2)
      colnames(X.meth.2)[1] = c("Age")
    }
    
    cv.fit <- cv.glmnet(x=Xmeth1,
                        Surv(time=y$y, event=y$Event,type="right"), 
                        family = "cox",alpha=alpha,maxit=2000,
                        penalty.factor=c(1,rep(1,ncol(Xmeth1)-1)),
                        nfolds=nfolds)
    
    fit <- glmnet(x=Xmeth1,
                  Surv(time=y$y, event=y$Event,type="right"),
                  family = "cox",alpha=alpha,
                  penalty.factor=c(1,rep(1,ncol(Xmeth1)-1)))
    
    coef <- coef(fit, s = cv.fit$lambda.min)
    ind_coef = which(colnames(Xmeth1)%in%rownames(coef)[which(coef!=0)])
    cox = coxph(Surv(time=y$y, event=y$Event,type="right")~ Xmeth1[,ind_coef])
    cIndex[3] = summary(cox)$concordance[1]
    logMod1 = cox$loglik[2]
    R2[3] = 1-exp((-2/n)*(logMod1-logNull))
    p = as.numeric(length(coef[coef!=0]))
    R2.adj[3] = 1-(1-R2[3])*(n-1)/(n-p-1)
 
     cv.fit.2 <- cv.glmnet(x=X.meth.2,
                        Surv(time=y$y, event=y$Event,type="right"), 
                        family = "cox",alpha=alpha,maxit=2000,
                        penalty.factor=c(1,rep(1,ncol(Xmeth1))),
                        nfolds=nfolds)
  
     fit.2 <- glmnet(x=X.meth.2,
                  Surv(time=y$y, event=y$Event,type="right"),
                  family = "cox",alpha=alpha,
                  penalty.factor=c(1,rep(1,ncol(Xmeth1)-1)))
  
    coef.2 <- coef(fit.2, s = cv.fit.2$lambda.min)
    ind_coef.2 = which(colnames(X.meth.2)%in%rownames(coef.2)[which(coef.2!=0)])
    cox = coxph(Surv(time=y$y, event=y$Event,type="right")~ X.meth.2[,ind_coef.2])
    cIndex[4] = summary(cox)$concordance[1]
    logMod1 = cox$loglik[2]
    R2[4] = 1-exp((-2/n)*(logMod1-logNull))
    p = as.numeric(length(coef.2[coef.2!=0]))
    R2.adj[4] = 1-(1-R2[4])*(n-1)/(n-p-1)
   

    X =cbind(y$Age,Gene)
    colnames(X)[1]=c("Age")
    
    cv.fit4 <- cv.glmnet(x=X,
                         Surv(time=y$y, event=y$Event,type="right"), 
                         family = "cox",alpha=alpha,maxit=1000,
                         penalty.factor=c(1,rep(1,ncol(X)-1)),
                         nfolds=nfolds)
    
    fit4 <- glmnet(x=X, Surv(time=y$y, event=y$Event,type="right"), 
                   family = "cox",alpha=alpha,
                   penalty.factor=c(1,rep(1,1,ncol(X)-1)))
    
    coef4 <- coef(fit4, s = cv.fit4$lambda.min)
    ind_coef4 = which(colnames(X)%in%rownames(coef4)[which(coef4!=0)])
    cox4 = coxph(Surv(time=y$y, event=y$Event,type="right")~ X[,ind_coef4])
    cIndex[2] = summary(cox4)$concordance[1]
    logMod4 = cox4$loglik[2]
    R2[2]= 1-exp((-2/n)*(logMod4-logNull))
    p = as.numeric(length(coef4[coef4!=0]))
    R2.adj[2] = 1-(1-R2[2])*(n-1)/(n-p-1)
 
    return(list(R2.adj=R2.adj,cIndex=cIndex,coef=coef,coef.2 =coef.2, coef.4=coef4))
}

