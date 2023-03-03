functions {
  // forecast_rng and egpd_lpdf vary by model
  vector forecast_rng(int n_pred, real sigma, real xi, real kappa1, real kappa2, real p) {
    vector[n_pred] forecast;
    vector[n_pred] a = rep_vector(0, n_pred);
    vector[n_pred] b = rep_vector(1, n_pred);
    array[n_pred] real u = uniform_rng(a, b);
    real cst = p * (1 - (1 + xi * (1.001 / sigma)) ^ (-1 / xi)) ^ kappa1 + 
              (1-p) * (1 - (1 + xi * (1.001 / sigma)) ^ (-1 / xi)) ^ kappa2;
    for (n in 1:n_pred) {
      real u_adj = u[n] * (1 - cst) + cst;
      if(u[n] < p) {
        forecast[n] = (sigma / xi) * ((1 - u_adj ^ (1 / kappa1)) ^ -xi - 1);
      }
      else {
        forecast[n] = (sigma / xi) * ((1 - u_adj ^ (1 / kappa2)) ^ -xi - 1);
      }
    }
    return forecast;
  }
  
  real egpd_lpdf(real y, real sigma, real xi, real kappa1, real kappa2, real p) {
    real lpdf;
    real w = 1 + xi * (y/sigma);
    real first = (kappa1 * p * (1-w^(-1/xi)))^(kappa1 - 1);
    real second = (kappa2 * (1-p) * (1-w^(-1/xi)))^(kappa2 - 1); 
    real cst_term = 1 - (1 + xi * (1.001/sigma)) ^ (-1/xi);
    real cst = p * cst_term ^ (kappa1 - 1) + (1 - p) * cst_term ^ (kappa2-1);
    lpdf = -log(sigma) - (1/xi + 1) * log(w) + log(first + second);
    return lpdf - log1m(cst);
  }
  
  // twCRPS and matnormal_lpdf remain unchanged across models
  real twCRPS(real y, vector forecast, real delta, real w_mean, real w_sd) {
    real score;
    real summand;
    int N = rows(forecast);
    summand = 0;
    for (n in 1:N) {
      summand += (forecast[n] - step(forecast[n] - y)) ^ 2
                 * normal_cdf(forecast[n] | w_mean, w_sd);
    }
    score = summand * delta;
    return score;
  }
  
  real matnormal_lpdf(matrix y, matrix cov, matrix corr) {
    real lpdf;
    real r = rows(corr);
    real p = rows(cov);
    lpdf = -(r * p / 2) * log(2 * pi()) - (p / 2) * log_determinant(corr)
           - (r / 2) * log_determinant(cov)
           - 0.5 * trace(mdivide_right_spd(mdivide_left_spd(corr, y'), cov) * y);
    return lpdf;
  }
}
data {
  int<lower=1> R; // # of regions
  int<lower=1> p; // # of parameters
  int<lower=1> T_all; // # of timepoints in full dataset
  int<lower=1> T_train;
  int<lower=1> T_hold;
  
  // covariate data
  array[R] matrix[T_all, p] X_full; // design matrix; 1-D array of size r with matrices t x p
  array[R] matrix[T_train, p] X_train; // design matrix; 1-D array of size r with matrices t x p
  
  // training data
  int<lower=1> N_tb_obs;
  int<lower=1> N_tb_mis;
  int<lower=1> N_tb_all;
  array[N_tb_obs] real<lower=1> y_train_obs; // burn area for observed training timepoints
  array[N_tb_obs] int<lower=1> ii_tb_obs;
  array[N_tb_mis] int<lower=1, upper=N_tb_all> ii_tb_mis;
  array[N_tb_all] int<lower=1, upper=N_tb_all> ii_tb_all; // for broadcasting
  array[T_train] int<lower=1> idx_train_er;
  
  // holdout data
  int<lower=1> N_hold_obs;
  int<lower=1> N_hold_all; // includes 'missing' and observed
  array[N_hold_obs] int<lower=1> ii_hold_obs; // vector of indices for holdout data timepoints
  array[N_hold_all] int<lower=1> ii_hold_all; // vector of indices for broadcasting to entire holdout dataset
  array[N_hold_obs] real<lower=1> y_hold_obs; // burn area for observed holdout timepoints
  array[T_hold] int<lower=1> idx_hold_er;
  
  // neighbor information
  int<lower=0> n_edges;
  array[n_edges] int<lower=1, upper=R> node1; // node1[i] adjacent to node2[i]
  array[n_edges] int<lower=1, upper=R> node2; // and node1[i] < node2[i]
  
  // indicator matrices for ecoregions
  matrix[R, R] l3;
  matrix[R, R] l2;
  matrix[R, R] l1;
  
  // indicator matrices for AR(1) penalization on spline coefficients of betas
  matrix[p, p] equal;
  matrix[p, p] bp_lin;
  matrix[p, p] bp_square;
  matrix[p, p] bp_cube;
  matrix[p, p] bp_quart;
}
transformed data {
  int S = 3; // # of parameters with regression (ranges from 1 to 4)
  int C = 4; // # of parameters with correlation (either regression or random intercept)
}
parameters {
  array[N_tb_mis] real<lower=1> y_train_mis;
  vector[R] Z; // xi
  real<lower = 0, upper = 1> prob;
  array[T_all, S] row_vector[R] phi_init;
  array[S] matrix[p, R] beta;
  array[S] real<lower=0> tau_init;
  array[S] real<lower=0, upper=1> eta;
  array[S] real<lower=0, upper=1> bp_init;
  array[C] vector<lower=0, upper=1>[2] rho; // ordering: 1,2=kappas, 3 = nu, 4 = xi
}
transformed parameters {
  array[N_tb_all] real<lower=1> y_train;
  array[S] matrix[T_all, R] phi;
  array[S] matrix[T_train, R] reg;
  array[S] matrix[p, p] cov_ar1;
  array[S] real<lower=0, upper=1> bp;
  array[S] real<lower=0> tau;
  array[C] matrix[R, R] corr;
  vector[R] ri_init; // random intercept vector
  matrix[T_all, R] ri_matrix; // broadcast ri_init to full matrix
  
  vector<lower=0>[N_tb_all] kappa1;
  vector<lower=0>[N_tb_all] kappa2;
  vector<lower=0>[N_tb_all] nu;
  vector<lower=0>[N_tb_all] xi;
  vector<lower=0>[N_tb_all] sigma;
  
  y_train[ii_tb_obs] = y_train_obs;
  y_train[ii_tb_mis] = y_train_mis;
  
  for (c in 1:C) {
    corr[c] = l3 + rho[c][2] * l2 + rho[c][1] * l1;
  }
  
  ri_init = cholesky_decompose(corr[4])' * Z;
  ri_matrix = rep_matrix(ri_init', T_all);
  
  for (s in 1:S) {
    bp[s] = bp_init[s] / 2;
    tau[s] = tau_init[s] / 2;
    cov_ar1[s] = equal + bp[s] * bp_lin + bp[s] ^ 2 * bp_square
                 + bp[s] ^ 3 * bp_cube + bp[s] ^ 4 * bp_quart;
    
    // ICAR variables
    phi[s][1, ] = 1 / tau[s] * phi_init[1, s];
    for (t in 2:T_all) {
      phi[s][t, ] = eta[s] * phi[s][t - 1, ]
                       + 1 / tau[s] * phi_init[t, s];
    }
    
    // regression for kappa, nu, and xi
    for (r in 1:R) {
      reg[s][, r] = X_train[r] * beta[s][, r] + phi[s][idx_train_er, r];
    }
  }
  
  kappa1 = exp(to_vector(reg[1]))[ii_tb_all];
  kappa2 = exp(to_vector(reg[2]))[ii_tb_all];
  nu = exp(to_vector(reg[3]))[ii_tb_all];
  xi = exp(to_vector(ri_matrix[idx_train_er,]))[ii_tb_all];
  sigma = nu ./ (1 + xi);
}
model {
  // priors on rhos and AR(1) penalization of splines
  prob ~ uniform(0, 1);
  Z ~ std_normal();
  to_vector(bp_init) ~ uniform(0, 1);
  
  // priors scaling constants in ICAR
  to_vector(eta) ~ beta(2, 8);
  to_vector(tau_init) ~ exponential(1);
  
  for (c in 1:C) {
    // rho[c][1] ~ beta(3,4);
    // soft constraint for sum of rhos within an individual param to be <= 1 (ie rho1kappa + rho2kappa <= 1)
    sum(rho[c]) ~ uniform(0, 1);
  }
  
  for (s in 1:S) {
    // MVN prior on betas
    target += matnormal_lpdf(beta[s] | cov_ar1[s], corr[s]);
    // ICAR prior
    for (t in 1:T_all) {
      target += -.5 * dot_self(phi_init[t, s][node1] - phi_init[t, s][node2]);
      sum(phi_init[t, s]) ~ normal(0, 0.001 * R);
    }
  }
  
  // likelihood
  for (n in 1:N_tb_all) {
    target += egpd_lpdf(y_train[n] | sigma[n], xi[n], kappa1[n], kappa2[n], prob);
  }
}

// generated quantities {
//   array[S] matrix[T_all, R] reg_full;
//   
//   vector<lower=0>[N_tb_obs] kappa1_train;
//   vector<lower=0>[N_tb_obs] kappa2_train;
//   vector<lower=0>[N_tb_obs] nu_train;
//   vector<lower=0>[N_tb_obs] xi_train;
//   vector<lower=0>[N_tb_obs] sigma_train;
//   
//   vector<lower=0>[N_hold_obs] kappa1_hold;
//   vector<lower=0>[N_hold_obs] kappa2_hold;
//   vector<lower=0>[N_hold_obs] nu_hold;
//   vector<lower=0>[N_hold_obs] xi_hold;
//   vector<lower=0>[N_hold_obs] sigma_hold;
//   
//   array[N_tb_obs] real train_loglik;
//   array[N_hold_obs] real holdout_loglik;
//   array[N_hold_obs] real holdout_twcrps;
//   
//   // variables needed for estimation of twCRPS integral via summation
//   real interval = max(y_hold_obs) - min(y_hold_obs);
//   int n_pred = 10000;
//   real delta = interval / n_pred;
//   
//   for (s in 1:S) {
//     for (r in 1:R) {
//       reg_full[s][, r] = X_full[r] * beta[s][, r] + phi[s][, r];
//     }
//   }
//   
//   kappa1_train = exp(to_vector(reg_full[1]))[ii_tb_all][ii_tb_obs];
//   kappa2_train = exp(to_vector(reg_full[2]))[ii_tb_all][ii_tb_obs];
//   nu_train = exp(to_vector(reg_full[3]))[ii_tb_all][ii_tb_obs];
//   xi_train = exp(to_vector(ri_matrix))[ii_tb_all][ii_tb_obs];
//   sigma_train = nu_train ./ (1 + xi_train);
//   
//   kappa1_hold = exp(to_vector(reg_full[1]))[ii_hold_all][ii_hold_obs];
//   kappa2_hold = exp(to_vector(reg_full[2]))[ii_hold_all][ii_hold_obs];
//   nu_hold = exp(to_vector(reg_full[3]))[ii_hold_all][ii_hold_obs];
//   xi_hold = exp(to_vector(ri_matrix))[ii_hold_all][ii_hold_obs];
//   sigma_hold = nu_hold ./ (1 + xi_hold);
//   
//   if (max(y_train_obs) < 50) {
//     // condition determines if the data read in are the sqrt or original burn areas
//     // training log-likelihood
//     for (n in 1:N_tb_obs) {
//       train_loglik[n] = egpd_lpdf(y_train_obs[n] | sigma_train[n], xi_train[n], kappa1_train[n], kappa2_train[n], prob)
//                         + log(0.5) - log(y_train_obs[n]);
//     }
//     // holdout scores
//     for (n in 1:N_hold_obs) {
//       // log-likelihood
//       holdout_loglik[n] = egpd_lpdf(y_hold_obs[n] | sigma_hold[n], xi_hold[n], kappa1_hold[n], kappa2_hold[n], prob)
//                           + log(0.5) - log(y_hold_obs[n]);
//       // twCRPS
//       holdout_twcrps[n] = twCRPS(y_hold_obs[n],
//                                  forecast_rng(n_pred, sigma_hold[n],
//                                               xi_hold[n], kappa1_hold[n], kappa2_hold[n], prob),
//                                  delta, sqrt(21), 3);
//     }
//   } else {
//     // training log-likelihood
//     for (n in 1:N_tb_obs) {
//       train_loglik[n] = egpd_lpdf(y_train_obs[n] | sigma_train[n], xi_train[n], kappa1_train[n], kappa2_train[n], prob);
//     }
//     // holdout scores
//     for (n in 1:N_hold_obs) {
//       // log-likelihood
//       holdout_loglik[n] = egpd_lpdf(y_hold_obs[n] | sigma_hold[n], xi_hold[n], kappa1_hold[n], kappa2_hold[n], prob);
//       // twCRPS 
//       holdout_twcrps[n] = twCRPS(y_hold_obs[n],
//                                  forecast_rng(n_pred, sigma_hold[n],
//                                               xi_hold[n], kappa1_hold[n], kappa2_hold[n], prob),
//                                  delta, 21, 9);
//     }
//   }
// }
// 
// 