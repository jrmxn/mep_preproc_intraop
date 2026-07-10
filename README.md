# mep_preproc_intraop

**Author:** J R McIntosh

`mep_preproc_intraop` is a MATLAB-based pipeline designed for the preprocessing, standardization, and analysis of intraoperative neurophysiological monitoring data, primarily focusing on Motor Evoked Potentials (MEPs). It offers a structured workflow for handling data exported from multiple Intraoperative Monitoring (IOM) systems, providing standard analysis routines, artifact rejection capabilities, and data visualizations.

## Key Features

1. **Multi-Vendor Data Conversion:** Contains converters to ingest data from different IOM software (Surgical Studio, Cascade Classic, EPWorks/xltek) and bring them into a unified MATLAB format.
2. **Standardization:** Transforms hardware-specific outputs into standardized `.mat` files containing both the electrophysiological traces (`_data.mat`) and metadata/event information (`_info.mat`).
3. **Data Analysis and Extraction:** Computes MEP features such as Area Under the Curve (AUC) and peak-to-peak amplitude.
4. **Artifact Rejection:** Provides scripts (`run_sp_rejection.m`) and interactive tools to review data and manually/semi-automatically reject noisy channels or trials.
5. **Experimental Visualization:** Scripts like `run_an_experimental_time.m` allow plotting experimental timelines, stimulation parameters (current/voltage), and resulting MEP properties over the course of a surgery or experiment.

## Directory Structure

* `ep_converters/`: Contains subdirectories and scripts for converting data from various IOM formats (Surgical Studio, Cascade EDFs, EPWorks) into the foundational JSON structure required by this pipeline. (See `ep_converters/README.md` for detailed instructions on exporting and converting data from these systems).
* `+sp/`: MATLAB package folder containing core processing functions for:
  * `standardise_modes.m`: Standardizing modes across participants.
  * `rejection.m`: Functions powering the trial/channel rejection UI.
  * `cluster_stim.m`: Logic for clustering stimulation events.
* `auxf/`: Auxiliary functions required by the main scripts. 
* `set_env.m`: Script to set up MATLAB paths and load environment variables from an `env.json` file.
```json
{
  "PROJECT": "2024-01-00_human_scs_working",
  "D_PROC": "/path/to/proc",
  "D_REPORTS": "/path/to/reports",
  "D_GIT_ROOT": "/path/to/gitprojects",
  "D_GIT": "/path/to/gitprojects/human_escs_analysis",
}
```
* `load_data.m`: Core utility for loading processed data into workspace memory, providing flags to calculate AUC, apply regressed shock artifacts, and more.
* `run_sp_standardise_modes.m`: Top-level script to invoke data standardization for specific cohorts or participants.
* `run_an_experimental_time.m`: Script for producing experimental timeline summary plots.
* `run_sp_rejection.m`: Script for running the artifact rejection interface.

## Quick Start & General Workflow

1. **Environment Setup:**
   Ensure you have created an `env.json` in the repository root or parent directory to define necessary paths (e.g., `D_USER`, `D_PROC`, `D_DATA`). 
   Run `set_env.m` to load these variables and configure paths.

2. **Convert Raw Data:**
   Follow instructions in `ep_converters/README.md` to export data from the IOM hardware (e.g., Surgical Studio) and augment it with necessary metadata (electrode level, laterality, approach, etc.).

3. **Standardize Data:**
   Once converted, open `run_sp_standardise_modes.m`. Update the participant mapping and participant ID to match your dataset, and run the script. This creates standardized `_data.mat` and `_info.mat` outputs in your preprocessing directory (`D_PROC`).

4. **Review and Reject Data:**
   Configure `cfg_rejection.json` to target your participant and desired modalities. Run `run_sp_rejection.m` to view the data and mark specific channels or trials for rejection.

5. **Analyze and Visualize:**
   Configure `cfg_experimental_time.json` for your participant. Run `run_an_experimental_time.m` to load the standardized data (via `load_data.m`), apply your rejections, and visualize experimental events alongside MEP responses over time.
