# mep_preproc_intraop

**Author:** J R McIntosh

`mep_preproc_intraop` is a MATLAB-based pipeline designed for the preprocessing, standardization, and analysis of intraoperative neurophysiological monitoring data, primarily focusing on Motor Evoked Potentials (MEPs). It offers a structured workflow for handling data exported from multiple Intraoperative Monitoring (IOM) systems, providing standard analysis routines, artifact rejection capabilities, and data visualizations.

## Key Features

1. **Multi-Vendor Data Conversion:** Contains converters to ingest data from different IOM software (Surgical Studio, Cascade Classic, EPWorks/xltek) and bring them into a unified MATLAB format.
2. **Standardization:** Transforms hardware-specific outputs into standardized `.mat` files containing both the electrophysiological traces (`_data.mat`) and metadata/event information (`_info.mat`).
3. **Data Analysis and Extraction:** Computes MEP features such as Area Under the Curve (AUC) and peak-to-peak amplitude.
4. **Artifact Rejection:** Provides scripts (`run_sp_rejection.m`) and interactive tools to review data and manually/semi-automatically reject noisy channels or trials.
5. **Experimental Visualization:** Scripts like `run_an_experimental_time.m` allow plotting experimental timelines, stimulation parameters (current/voltage), and resulting MEP properties over the course of a surgery or experiment.

## Dependencies & Setup

1. **Initial Git Setup**: If you are new to Git and want to use this pipeline, open your terminal (or Git Bash) and clone the repository to your local machine:
   ```bash
   git clone https://github.com/jrmxn/mep_preproc_intraop.git
   cd mep_preproc_intraop
   ```
2. **Git Submodules**: This repository utilizes third-party libraries (e.g. `loadjson`, `toml.read`) located in the `auxf/` folder via Git submodules. After cloning, you must fetch these submodules to ensure the libraries are downloaded:
   ```bash
   git submodule update --init --recursive
   ```
3. **MATLAB Toolboxes**: Ensure you have the following MATLAB toolboxes installed:
   - Statistics and Machine Learning Toolbox (e.g., for `fitlm`, `kmeans`)
   - Signal Processing Toolbox (e.g., for `butter`, `filtfilt`, `designfilt`)
4. **Environment and Configurations**: 
   - You need an `env.json` file to define paths. It can live in the same directory as this README (for standalone usage) or one directory above it.
   - You need a `run_cfg` folder containing configuration files (`cfg_rejection.json`, `cfg_experimental_time.json`). This folder can also live in the current directory (for standalone usage) or one directory above it.
   - You need a participant mapping folder (defined by `D_PARTICIPANT_MAPPING` in your `env.json`) to store your `.toml` study mapping files.

## Directory Structure

* `ep_converters/`: Contains subdirectories and scripts for converting data from various IOM formats (Surgical Studio, Cascade EDFs, EPWorks) into the foundational JSON structure required by this pipeline. (See `ep_converters/README.md` for detailed instructions on exporting and converting data from these systems).
* `+sp/`: MATLAB package folder containing core processing functions for:
  * `standardise_modes.m`: Standardizing modes across participants.
  * `rejection.m`: Functions powering the trial/channel rejection UI.
  * `cluster_stim.m`: Logic for clustering stimulation events.
* `auxf/`: Auxiliary functions required by the main scripts. 
* `exporters/`: Contains scripts for exporting the standardized and cleaned data into simpler formats for external analysis or sharing.
* `set_env.m`: Script to set up MATLAB paths and load environment variables from an `env.json` file.
```json
{
  "PROJECT": "2024-01-00_human_scs_working",
  "D_PROC": "/path/to/proc",
  "D_DATA": "/path/to/raw_data",
  "D_PARTICIPANT_MAPPING": "/path/to/participant_mapping_files",
  "D_REPORTS": "/path/to/reports",
  "D_GIT": "/path/to/gitprojects/human_escs_analysis"
}
```

### Participant Mapping

The `D_PARTICIPANT_MAPPING` path inside `env.json` (e.g., `/home/mcintosh/Cloud/DataPort/2024-01-00_human_scs_working/auxillary/participant_mapping/`) is used to store `.toml` files that assign original unique participant IDs to standardized study-specific IDs.

The name of the `.toml` file is critically important. When using scripts like `load_data.m`, the string you provide for the `participant_mapping` parameter must exactly match the filename of your mapping file (without the extension). For example, providing `'participant_mapping', 'scap_study'` instructs the pipeline to load `scap_study.toml`.

**Example structure of a mapping file (`scap_study.toml`):**
```toml
alias_modifier = "SCAP"
reject_modes = ["research_scs", "research_mep", "research_paired_averaged", "research_paired_repeat"]

[participant]
cornptio024 = 1 # comments about the recording
scapptio032 = 2 # e.g. SCAP with immediate check of effects...
scapptio033 = 3 
```

- `alias_modifier`: String used as a prefix for the resulting analysis alias (e.g., "SCAP" + "1" -> "SCAP01").
- `reject_modes`: An array specifying which modes should undergo artifact rejection checks.
- `[participant]`: A block mapping the original subject IDs (like `cornptio024`) to a simplified study ID (`1`, `2`, `3`, etc.).

* `load_data.m`: Core utility for loading processed data into workspace memory, providing flags to calculate AUC, apply regressed shock artifacts, and more.
* `run_sp_standardise_modes.m`: Top-level script to invoke data standardization for specific cohorts or participants.
* `run_an_experimental_time.m`: Script for producing experimental timeline summary plots.
* `run_sp_rejection.m`: Script for running the artifact rejection interface.

## Configuration Files

You must configure specific JSON files inside your `run_cfg` folder before running scripts. These files specify an array of `main_conditions`, of which you typically set one to `"enabled": true`.

**`cfg_experimental_time.json`**
Used by `run_an_experimental_time.m` to specify what data to load and plot. Required fields in the enabled block include:
- `participant_filter`: Array of participant IDs (e.g., `["scapptio125"]`)
- `participant_mapping`: Name of the TOML mapping file to use (e.g., `"scap_study"`)
- `ephys_mode`: The mode to analyze (e.g., `"research_scs"`)

**`cfg_rejection.json`**
Used by `run_sp_rejection.m` to specify targets for artifact rejection. Requires:
- `participant`: The ID string (e.g., `"cdmrpptsc005"`)
- `participant_mapping`: Name of the mapping file (e.g., `"cdmrp_study"`)
- `vec_ephys_mode`: Array of modes to iterate over (e.g., `["research_lcswap", "research_scs"]`)
- `fs_lowpass`: Frequency for the lowpass filter in Hz (e.g., `200`)
- `reject_mode`: Array dictating actions (e.g., `["reject_lines", "update_table"]`)

## Quick Start & General Workflow

1. **Environment Setup:**
   Ensure you have created an `env.json` in the repository root or parent directory to define necessary paths (e.g., `D_PROC`, `D_DATA`). 
   Run `set_env.m` to load these variables and configure paths.

2. **Convert Raw Data:**
   Follow instructions in `ep_converters/README.md` to export data from the IOM hardware (e.g., Surgical Studio) and augment it with necessary metadata (electrode level, laterality, approach, etc.).

3. **Standardize Data:**
   Once converted, open `run_sp_standardise_modes.m`. Update the participant mapping and participant ID to match your dataset, and run the script. This creates standardized `_data.mat` and `_info.mat` outputs in your preprocessing directory (`D_PROC`).

4. **Review and Reject Data:**
   Configure `cfg_rejection.json` to target your participant and desired modalities. Run `run_sp_rejection.m` to view the data and mark specific channels or trials for rejection.

5. **Analyze and Visualize:**
   Configure `cfg_experimental_time.json` for your participant. Run `run_an_experimental_time.m` to load the standardized data (via `load_data.m`), apply your rejections, and visualize experimental events alongside MEP responses over time.

6. **Export Data (Optional):**
   If you need to analyze the data outside of this MATLAB pipeline, modify and run `exporters/simple_export.m`. This script loads the standardized data, removes trials flagged during the artifact rejection step, sanitizes units/metadata, and exports the data into `D_PROC/preproc_tables/export_folder/`. For each participant, it generates:
   - A `_table.csv` file with flattened metadata and response features (e.g., stimulation settings, AUC, pkpk).
   - An `_ep_matrix.mat` file containing the continuous electrophysiology traces (`[trials x time x channels]`).
   - A `_cfg_proc.toml` file detailing channel lists, sampling frequencies, and physical units.
