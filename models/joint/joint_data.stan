data {
  int<lower=1> R; // # of regions
  int<lower=1> p; // # of parameters in largest model component (count model in this case)
  int<lower=1> p_size; // # of parameters in size model component
  int<lower=1> T_all; // # of timepoints in full dataset
  int<lower=1> T_train;
  int<lower=1> T_hold;

  // covariate data
  array[R] matrix[T_all, p] X_full_count; // full design matrix for count component
  array[R] matrix[T_train, p] X_train_count; // training data only
  array[R] matrix[T_all, p_size] X_full_size; // full design matrix for size component
  array[R] matrix[T_train, p_size] X_train_size; // training data only

  // area offset
  array[R] real area_offset; // known offset vector of areas
  
  // lower bound of sizes
  real y_min;

  // training data
  int<lower=1> N_ts_obs;
  int<lower=1> N_ts_mis;
  int<lower=1> N_ts_all;
  array[N_ts_obs] real<lower=y_min> y_train_size_obs; // burned area for observed training timepoints
  array[T_train, R] int<lower=0> y_train_count; // response data for counts
  array[N_ts_obs] int<lower=1> ii_ts_obs;
  array[N_ts_mis] int<lower=1, upper=N_ts_all> ii_ts_mis;
  array[N_ts_all] int<lower=1, upper=N_ts_all> ii_ts_all; // for broadcasting
  array[T_train] int<lower=1> idx_train_er;

  // holdout data
  int<lower=1> N_hold_obs;
  int<lower=1> N_hold_all; // includes 'missing' and observed
  array[N_hold_obs] int<lower=1> ii_hold_obs; // vector of indices for holdout data timepoints
  array[N_hold_all] int<lower=1> ii_hold_all; // vector of indices for broadcasting to entire holdout dataset
  array[N_hold_obs] real<lower=1> y_hold_size_obs; // burned area for observed holdout timepoints
  array[T_hold, R] int<lower=0> y_hold_count; // holdout data for count
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
  
  // twCRPS approximation
  int<lower=1> n_int;
  real<lower=1> int_range;
  vector<lower=y_min>[n_int] int_pts;
}