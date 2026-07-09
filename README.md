# Introduction

**Author:** J R McIntosh

## Standardisation of data

This was meant to be able to combine data from multile IOM hardware. It follows after running the ep_converters.

1. **Standardize Data:**
    - Navigate to `sp_preproc > run_sp_standarise_modes`.
    - Change the patient to the current number (e.g., `'scapptio113'`).
    - Standardized data is now located in `your_preprocessing_directory > preproc_standard > scapptio113 > ephys`.
    - These files (`scapptio113_data.mat` and `scapptio113_info.mat`) go to Natasha.
2. **Run `run_an_experiment_time`:**
    - Directly modify the conflict file before running the script (e.g., for `'scapptio113'`). This can be done by creating a breakpoint at line 15.
    - Run the script.
3. **Run `run_sp_rejection`:**
    - Modify the conflict file for `'scapptio113'` in `...\your_preprocessing_directory\auxillary\experimental_timings\immediate_study_extended`.
    - Run the script.
    - Adjust reject for each muscle. Close the window and the next mode will load. Repeat this process (adjust reject > close window).
