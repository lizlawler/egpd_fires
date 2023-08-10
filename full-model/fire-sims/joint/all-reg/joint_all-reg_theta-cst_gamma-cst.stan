functions {
  #include /../../burns/gpd_fcns.stanfunctions
  #include /../../burns/g1/stan/g1_fcns.stanfunctions
  #include /../../burns/twcrps_matnorm_fcns.stanfunctions
}
#include /../joint_data.stan
transformed data {
  int S = 3; // # of parameters with regression (ranges from 2 to 3)
  //ordering of S: 1 = lambda, 2 = kappa, 3 = sigma
  int C = 6; // # of parameters with correlation (either regression or random intercept)
}
parameters {
  array[N_tb_mis] real<lower=y_min> y_train_burn_mis;
  matrix[R, C-S] Z; // ordering: 1 = pi, 2 = delta, 3 = xi
  array[T_all, S] row_vector[R] phi_init;
  matrix[p, R] beta_count;
  array[2] matrix[p_burn, R] beta_burn;
  vector<lower=0>[S] tau_init;
  vector<lower=0, upper = 1>[S] eta;
  vector<lower=0, upper = 1>[S] bp_init;
  // ordering of C: 1 = lambda, 2 = kappa, 3 = sigma, 4 = pi, 5 = delta, 6 = xi
  vector<lower=0, upper = 1>[C] rho1;
  vector<lower=rho1, upper = 1>[C] rho_sum;
  real theta; // constant shared random effect
  vector[2] gamma; // scaling constant for linking theta; only used in burn links; 1= kappa, 2 = sigma
}
transformed parameters {
  array[N_tb_all] real<lower=y_min> y_train_burn;
  vector<lower = 0>[R] delta;
  matrix[T_train, R] lambda;
  vector[R] pi_prob;
  array[S] matrix[T_all, R] phi;
  array[S] matrix[T_train, R] reg;
  vector<lower=0>[S] bp = bp_init / 2;
  vector<lower=0>[S] tau = tau_init / 2;
  vector[C] rho2 = rho_sum - rho1;
  array[S] cov_matrix[p] cov_ar1;
  array[C] corr_matrix[R] corr;
  
  vector[R] ri_init; // random intercept vector
  matrix[T_all, R] ri_matrix; // broadcast ri_init to full matrix
  
  y_train_burn[ii_tb_obs] = y_train_burn_obs;
  y_train_burn[ii_tb_mis] = y_train_burn_mis;
  
  for (c in 1:C) {
    corr[c] = l3 + rho2[c] * l2 + rho1[c] * l1;
  }

  pi_prob = cholesky_decompose(corr[4])' * Z[,1];
  delta = exp(cholesky_decompose(corr[5])' * Z[,2]);  
  ri_init = cholesky_decompose(corr[6])' * Z[,3];
  ri_matrix = rep_matrix(ri_init', T_all);

  for (s in 1:S) {
    cov_ar1[s] = equal + bp[s] * bp_lin + bp[s] ^ 2 * bp_square
                 + bp[s] ^ 3 * bp_cube + bp[s] ^ 4 * bp_quart;
    
    // ICAR variables
    phi[s][1, ] = 1 / tau[s] * phi_init[1, s];
    for (t in 2:T_all) {
      phi[s][t, ] = eta[s] * phi[s][t - 1, ]
                       + 1 / tau[s] * phi_init[t, s];
    }
  }

  // regression link for lambda (counts), and kappa and sigma (burns)
  for (s in 2:S) {
    for (r in 1:R) {
      lambda[, r] = X_train_count[r] * beta_count[, r] + phi[1][idx_train_er, r] + area_offset[r] + theta;
      reg[s-1][, r] = X_train_burn[r] * beta_burn[s-1][, r] + phi[s][idx_train_er, r] + gamma[s-1] * theta;
    }
  }
}
model {
  theta ~ normal(0, 5);
  to_vector(gamma) ~ normal(0, 5);
  
  vector[N_tb_all] kappa = exp(to_vector(reg[1]))[ii_tb_all];
  vector[N_tb_all] sigma = exp(to_vector(reg[2]))[ii_tb_all];
  vector[N_tb_all] xi = exp(to_vector(ri_matrix[idx_train_er,]))[ii_tb_all];
  
  to_vector(Z) ~ std_normal();
  
  // prior on AR(1) penalization of splines
  to_vector(bp_init) ~ uniform(0, 1);
  
  // priors scaling constants in ICAR
  to_vector(eta) ~ beta(3, 4);
  to_vector(tau_init) ~ exponential(1);

  // prior on rhos
  to_vector(rho1) ~ beta(3, 4);
  to_vector(rho_sum) ~ beta(8, 2);
  
  // MVN prior on betas
  // first, for lambda - has 37 covariates
  target += matnormal_lpdf(beta_count | cov_ar1[1], corr[1]);
  // then, for kappa and simga - each have 13 covariates
  for (s in 2:S) {
    target += matnormal_lpdf(beta_burn[s-1] | cov_ar1[s][1:p_burn, 1:p_burn], corr[s]);
  }
  for (s in 1:S) {
    // ICAR prior
    for (t in 1:T_all) {
      target += -.5 * dot_self(phi_init[t, s][node1] - phi_init[t, s][node2]);
      sum(phi_init[t, s]) ~ normal(0, 0.001 * R);
    }
  }
  
  // burn likelihood
  for (n in 1:N_tb_all) {
    target += egpd_trunc_lpdf(y_train_burn[n] | y_min, sigma[n], xi[n], kappa[n]);
  }

  // count likelihood
  for (r in 1:R) {
    for (t in 1:T_train) {
      if (y_train_count[t, r] == 0) {
        target += log_sum_exp(bernoulli_logit_lpmf(1 | pi_prob[r]),
                              bernoulli_logit_lpmf(0 | pi_prob[r])
                              + neg_binomial_2_log_lpmf(y_train_count[t, r] | lambda[t, r], delta[r]));
      } else {
        target += bernoulli_logit_lpmf(0 | pi_prob[r])
                  + neg_binomial_2_log_lpmf(y_train_count[t, r] | lambda[t, r], delta[r]);
      }
    }
  }
}

generated quantities {
  matrix[T_train, R] train_loglik_count;
  matrix[T_hold, R] holdout_loglik_count;
  array[N_tb_obs] real train_loglik_burn;
  array[N_hold_obs] real holdout_loglik_burn;
  array[N_tb_obs] real train_twcrps;
  array[N_hold_obs] real holdout_twcrps;  

  array[2] matrix[T_all, R] reg_full;

  // expected value of all parameters based on all timepoints, then cut to only be holdout parameters
  for (s in 2:S) {
    for (r in 1:R) {
      reg_full[s-1][, r] = X_full_burn[r] * beta_burn[s-1][, r] + phi[s][, r] + gamma[s-1] * theta;
    }
  }

  // vector[N_tb_obs] kappa_train = exp(to_vector(reg_full[1]))[ii_tb_all][ii_tb_obs];
  // vector[N_tb_obs] sigma_train = exp(to_vector(reg_full[2]))[ii_tb_all][ii_tb_obs];
  // vector[N_tb_obs] xi_train = exp(to_vector(ri_matrix))[ii_tb_all][ii_tb_obs];
  
  // vector[N_hold_obs] kappa_hold = exp(to_vector(reg_full[1]))[ii_hold_all][ii_hold_obs];
  // vector[N_hold_obs] sigma_hold = exp(to_vector(reg_full[2]))[ii_hold_all][ii_hold_obs];
  // vector[N_hold_obs] xi_hold = exp(to_vector(ri_matrix))[ii_hold_all][ii_hold_obs];
  
  // burn component scores
  // training scores
  for (n in 1:N_tb_obs) {
    real kappa_train = exp(to_vector(reg_full[1]))[ii_tb_all][ii_tb_obs][n];
    real sigma_train = exp(to_vector(reg_full[2]))[ii_tb_all][ii_tb_obs][n];
    real xi_train = exp(to_vector(ri_matrix))[ii_tb_all][ii_tb_obs][n];
    
    train_loglik_burn[n] = egpd_trunc_lpdf(y_train_burn_obs[n] | y_min, sigma_train, xi_train, kappa_train);
    // forecasting then twCRPS, on training dataset
    vector[n_int] pred_probs_train = prob_forecast(n_int, int_pts_train, y_min, 
                                            sigma_train, xi_train, kappa_train);
    train_twcrps[n] = twCRPS(y_train_burn_obs[n], n_int, int_train, int_pts_train, pred_probs_train);
  }
  // holdout scores
  for (n in 1:N_hold_obs) {
    real kappa_hold = exp(to_vector(reg_full[1]))[ii_hold_all][ii_hold_obs][n];
    real sigma_hold = exp(to_vector(reg_full[2]))[ii_hold_all][ii_hold_obs][n];
    real xi_hold = exp(to_vector(ri_matrix))[ii_hold_all][ii_hold_obs][n];
    
    // log-likelihood
    holdout_loglik_burn[n] = egpd_trunc_lpdf(y_hold_burn_obs[n] | y_min, sigma_hold, xi_hold, kappa_hold);
      // forecasting then twCRPS, on holdout dataset
    vector[n_int] pred_probs_hold = prob_forecast(n_int, int_pts_train, y_min, 
                                          sigma_hold, xi_hold, kappa_hold);
    holdout_twcrps[n] = twCRPS(y_hold_burn_obs[n], n_int, int_train, int_pts_train, pred_probs_hold);
  }

  // count component scores
  // training log-likelihood
  for (r in 1:R) {
    for (t in 1:T_train) {
      if (y_train_count[t, r] == 0) {
        train_loglik_count[t, r] = log_sum_exp(bernoulli_logit_lpmf(1 | pi_prob[r]),
                                         bernoulli_logit_lpmf(0 | pi_prob[r])
                                         + neg_binomial_2_log_lpmf(y_train_count[t, r] | lambda[t, r], delta[r]));
      } else {
        train_loglik_count[t, r] = bernoulli_logit_lpmf(0 | pi_prob[r])
                             + neg_binomial_2_log_lpmf(y_train_count[t, r] | lambda[t, r], delta[r]);
      }
    }
  }
  
  // holdout log-likelihood
  for (r in 1:R) {
    vector[T_hold] lambda_hold = (X_full_count[r] * beta_count[, r] + phi[1][, r])[idx_hold_er] + area_offset[r] + theta;
    for (t in 1:T_hold) {
      if (y_hold_count[t, r] == 0) {
        holdout_loglik_count[t, r] = log_sum_exp(bernoulli_logit_lpmf(1 | pi_prob[r]),
                                           bernoulli_logit_lpmf(0 | pi_prob[r])
                                           + neg_binomial_2_log_lpmf(y_hold_count[t, r] | lambda_hold[t], delta[r]));
      } else {
        holdout_loglik_count[t, r] = bernoulli_logit_lpmf(0 | pi_prob[r])
                               + neg_binomial_2_log_lpmf(y_hold_count[t, r] | lambda_hold[t], delta[r]);
      }
    }
  }
}