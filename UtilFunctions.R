# Function called in main code

# -x : vector or matrix containing explanatory variables
# -y : vector or matrix containing response variables
# -alpha = penalty term in the glmnet function, the default alpha = 1 corresponds to the lasso penalty
# -nfolds = number of folds used in cross-validation procedure of the glmnet function 

regression <- function(x, y, alpha=1, nfolds=10)
{
  res = list(active=NULL, active_index=NULL, inter =NULL, cv.fit=NULL)
  if ((ncol(x) == 1) & (ncol(y) == 1))
  {
    regress = lm(y~x)
    pvalue = summary(regress)$coef[2,4]
    if (pvalue<0.05)
    {
      res$active = summary(regress)$coef[2,1]
      res$active_index = 1
      names(res$active_index) = colnames(x)
      res$inter = summary(regress)$coef[1,1]
      res$cv.fit = regress
    }
    else{
      res$active_index=numeric(0)
      res$active=0
      res$inter = summary(lm(y~1))$coef[1,1]
      res$cv.fit=lm(y~1)
    }
  }
  else{
    if ( (ncol(x) != 1) & (ncol(y) == 1))
    {
      fit <- glmnet(x=x,y=y,alpha=alpha)
      cv.fit <- cv.glmnet(x=x,y=y,alpha=alpha,nfolds=nfolds)
      coef <- coef(fit, s = cv.fit$lambda.min)
      res$inter = coef[1]
      nom = rownames(coef)[-1]
      coef = coef[-1]
      names(coef) = nom
      res$active_index <- which(coef != 0)
      if (length(res$active_index) >= 1){
        ind_x = which(colnames(x)%in%names(res$active_index))
        ana = lm(y ~ x[,ind_x] )
        coef = ana$coef
        res$inter = coef[1]
        coef = coef[-1]
        names(coef) = names(res$active_index)
        coef[is.na(coef)] = 0
        res$active = coef
      }else{
        res$active <- coef[res$active_index]
      }
      res$cv.fit = cv.fit
    }    
    else{
      fit <- glmnet(x=x, y=y, alpha=alpha, family="mgaussian" )
      cv.fit <- cv.glmnet(x=x, y=y, alpha=alpha, family="mgaussian" )
      n = ncol(y)
      ind = which(cv.fit$lambda==cv.fit$lambda.min)
      coef = fit$beta
      coef = lapply(coef,function(y){y[,ind]})
      select = which(coef[[1]] != 0)
      select = which(colnames(x)%in%names(select))
      res$active_index <- which(coef[[1]] != 0)
      data = data.frame(y,x[,select])
      names(data) = c(colnames(y),colnames(x)[select])
      prior<-list(B = list(mu=rep(0,(length(select)+1)*n),
      	V=10^8*diag((length(select)+1)*n)), R=list(V=diag(n),nu=0.002))
      obs = paste(paste("cbind(",paste(colnames(y),collapse=",")),")")
      if (length(select)!=0){
        var = paste(paste("trait:(",paste(colnames(x)[select],collapse="+")),")+trait-1")
        form = as.formula(paste(obs, var,sep=" ~ "))
        m1<-MCMCglmm(form,            
                     rcov=~us(trait):units,family=rep("gaussian",n),
                     nitt=5000,burnin=1000,thin=1,prior=prior,data = data,verbose=FALSE) 
        para <- c(apply(m1$Sol,2,mean))
        seq = rep((1:n),1+length(select))
        res$active = lapply(as.matrix(1:n), function(x){para[seq==x]})
        names(res$active) = colnames(y)
        res = lapply(res$active,function(y)
        		{list(active_index= res$active_index,active=y[2:(length(select)+1)],inter=y[1],cv.fit=cv.fit)})          
      } else {
        res$active_index <- which(coef[[1]] != 0)
        res$active = lapply(coef, function(y){y[res$active_index]})
        res = lapply(res$active,function(y)
        		{list(active_index= res$active_index,active=y,inter=c(0),cv.fit=cv.fit)})  
      }
    }
  }
  return(res)
}  
