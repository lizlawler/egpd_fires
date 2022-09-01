functions {
  real egpd_g1_lpdf(real y, real sigma, real xi, real kappa) {
    real lpdf;
    lpdf = log(kappa) - log(sigma) - (1/xi + 1) * log(1 + xi * (y/sigma)) + 
    (kappa-1) * log(1 - (1 + xi * (y/sigma))^(-1/xi));
    return lpdf;
  }
}

data {
  int<lower = 1> p; // # of parameters
  int<lower = 1> n; // # of observations
  int<lower = 1> r; // # of regions
  int<lower=0> N_edges;
  int<lower=1, upper = r> node1[N_edges];  // node1[i] adjacent to node2[i]
  int<lower=1, upper = r> node2[N_edges];  // and node1[i] < node2[i]
  
  matrix[n, p] X; // design matrix
  vector[n*r] y; // response data
  
  // indicator matrices for ecoregions
  matrix[r, r] l3;
  matrix[r, r] l2;
  matrix[r, r] l1;

  // indicator matrices for AR(1) process on betas
  matrix[p, p] equal;
  matrix[p, p] bp_lin;
  matrix[p, p] bp_square;
  matrix[p, p] bp_cube;
  matrix[p, p] bp_quart;
}

parameters {
  row_vector[r] phi;
  matrix[p, r] Z_kappa;
  matrix[p, r] beta_xi;
  matrix[p, r] beta_nu;
  real<lower = 0, upper = 1> bp_init;
  real<lower = 0, upper = 1> rho2;
  real<lower=0, upper = (1-rho2)> rho1;
}

transformed parameters {
  matrix[n, r] phi_mat = rep_matrix(phi, n);

  real<lower=0, upper = bp_init/2> bp = bp_init/2;
  
  matrix[r, r] corr_kappa = l3 + rho2 * l2 + rho1 * l1;
  matrix[p, p] cov_ar1 = equal + bp * bp_lin + bp^2 * bp_square + bp^3 * bp_cube + bp^4 * bp_quart;
  matrix[p, r] beta_kappa = cholesky_decompose(cov_ar1)' * Z_kappa * cholesky_decompose(corr_kappa);

  vector[n*r] kappa;
  vector[n*r] nu;
  vector[n*r] xi;
  vector[n*r] sigma;
  
  kappa = to_vector(exp(X * beta_kappa/5 + phi_mat/10));
  nu = to_vector(exp(X * beta_nu));
  xi = to_vector(exp(X * beta_xi/5));
  for (i in 1:(n*r)) {
    sigma[i] = nu[i] / (1 + xi[i]);
  }
}

model {
  // priors
  to_vector(Z_kappa) ~ normal(0, 1);
  to_vector(beta_xi) ~ normal(0, 1);
  to_vector(beta_nu) ~ normal(0, 1);
  
  bp_init ~ uniform(0, 1);
  
  rho1 ~ beta(1.5, 4);
  rho2 ~ beta(3, 4);
  
  target += -0.5 * dot_self(phi[node1] - phi[node2]);
  // soft sum-to-zero constraint on phi)
  sum(phi) ~ normal(0, 0.001*r);
  
  // likelihood
  for (i in 1:(n*r)) {
    target += egpd_g1_lpdf(y[i] | sigma[i], xi[i], kappa[i]);
  }
}