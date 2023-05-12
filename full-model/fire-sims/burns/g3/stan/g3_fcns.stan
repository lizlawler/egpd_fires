functions{
#include /../../twcrps_matnorm_fcns.stan
#include /../../gpd_fcns.stan
  // custom distribution functions of EGPD
  real egpd_lpdf(real y, real sigma, real xi, real gamma) {
    real alpha = 1/gamma;
    real beta = 2;
    if (gamma > 1e-15) {
      return log(gamma) + (gamma-1) * gpareto_lccdf(y | sigma, xi) + 
              gpareto_lpdf(y | sigma, xi) + 
              beta_lpdf(exp(gamma * gpareto_lccdf(y | sigma, xi)) | alpha, beta);
    }
    else {
      reject("gamma<=0; found gamma = ", gamma);
    }
  }  
  real egpd_cdf(real y, real sigma, real xi, real gamma) {
    real alpha = 1/gamma;
    real beta = 2;
    if (gamma > 1e-15) {
      return exp(log1m_exp(beta_lcdf(exp(gamma * gpareto_lccdf(y | sigma, xi)) | alpha, beta)));
    }
    else {
      reject("gamma<=0; found gamma = ", gamma);
    }
  }
  real egpd_lcdf(real y, real sigma, real xi, real gamma) {
    real alpha = 1/gamma;
    real beta = 2;
    if (gamma > 1e-15) {
      return log1m_exp(beta_lcdf(exp(gamma * gpareto_lccdf(y | sigma, xi)) | alpha, beta));
    }
    else {
      reject("gamma<=0; found gamma = ", gamma);
    }
  }  
  real egpd_lccdf(real y, real sigma, real xi, real gamma) {
    real alpha = 1/gamma;
    real beta = 2;
    if (gamma > 1e-15) {
      return beta_lcdf(exp(gamma * gpareto_lccdf(y | sigma, xi)) | alpha, beta);
    }
    else {
      reject("gamma<=0; found gamma = ", gamma);
    }
  }  
  // truncated EGPD distribution
  real egpd_trunc_lpdf(real y, real ymin, real sigma, real xi, real gamma) {
    real lpdf = egpd_lpdf(y | sigma, xi, gamma);
    real cst = egpd_lccdf(ymin | sigma, xi, gamma);
    return lpdf - cst;
  }
  //forecast function
  // vector forecast_rng(int n_pred, real ymin, real sigma, real xi, real kappa) {
  //   vector[n_pred] forecast;
  //   vector[n_pred] a = rep_vector(0, n_pred);
  //   vector[n_pred] b = rep_vector(1, n_pred);
  //   array[n_pred] real u = uniform_rng(a, b);
  //   real cst = (1 - (1 + xi * (ymin / sigma)) ^ (-1 / xi)) ^ kappa;
  //   for (n in 1:n_pred) {
  //     real u_adj = u[n] * (1 - cst) + cst;
  //     forecast[n] = (sigma / xi) * ((1 - u_adj ^ (1 / kappa)) ^ -xi - 1);
  //   }
  //   return forecast;
  // }
}