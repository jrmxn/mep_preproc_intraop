# Introduction

**Author:** J R McIntosh

## Summary

TODO: Add summary.

## Steps to Process Data

1. The base data for everything is going to be a JSON file.
2. The JSON file comes along with an info `.mat` file that has a table for each mode.
3. In a `proc` folder, you write two `.mat` files: one info flattened, and one mode flattened.

> **Note:** Surgical Studio is for JSON files only. `cascade_classic` handles both Surgical Studio and Cascade Classic EDF formats.

## General Workflow

- Copy over:
  - Data to `raw` and `raw_backup`
  - Audio
  - Zeiss
  - Partial RTF contents to EN
- Do one of the export steps below.
- **Legacy / Unsure Steps:**
  - `run_sp_merge_subjects` <--- NOT ANYMORE
  - `run_sp_rejection` - (actually do it!)
  - `run_sp_cluster_stim` <--- NOT ANYMORE
- Back up on Apricorn HDD (not USB) and AES-256 encrypted on secure cloud.
- Ask for MRIs.

## Export Methods

### Surgical Studio (JSON)

This is the preferred method now. The following is an example workflow for a specific participant (e.g., Participant 113) prepared by Noah Noah Willett.

1. Create a new participant folder using the template.
2. Export the `.json` file from Surgical Studio in the form of case data.
3. In MATLAB, go to mep_preproc_intraop > ep_converters > Surgical studio > run_sp_surgical_studio_augment`.
4. Run the script.
5. Edit the configuration in Notepad or Notepad++ to match this structure (if needed):

   ```json
   {
       "main_conditions": [
           {
               "enabled": true,
               "augment_op": "write",
               "overwrite": true,
               "participant_ix": [113],
               "participant_prefix": "scapptio",
               "data_directory": "D_DATA_SCAP"
           }        
       ],
       "cfg": {
           "allow_multiple_enabled": false
       },
       "notes": {
           "augment_op": "augment or write"
       }
   }
   ```

6. Run the script again.
7. In File Explorer, navigate to: `your_exported_data_directory > scapptio113 > ephys > cadwell-iomax`.
8. The file `scapptio113_events_write` will populate here. Rename it to `scapptio113_events_augment`. This is what MATLAB will load back in.
9. Open `scapptio113_events_augment` (it is an Excel file you will edit).
10. Add in the level, laterality, electrode type, orientation, stimulation type, and approach. Annotate the Excel file using the template.
11. Change your configuration JSON to use the `"augment"` operation and save:

    ```json
    {
        "main_conditions": [
            {
                "enabled": true,
                "augment_op": "augment",
                "overwrite": true,
                "participant_ix": [113],
                "participant_prefix": "scapptio",
                "data_directory": "D_DATA_SCAP"
            }        
        ],
        "cfg": {
            "allow_multiple_enabled": false
        },
        "notes": {
            "augment_op": "augment or write"
        }
    }
    ```

12. Close the Excel file and then run `run_sp_surgical_studio_augment.m` again.
13. Add the participant to the `immediate_extended` study list as directed (e.g., `scap 113 = 74`).
14. **Standardize Data:**
    - Navigate to `sp_preproc > run_sp_standarise_modes`.
    - Change the patient to the current number (e.g., `'scapptio113'`).
    - Standardized data is now located in `your_preprocessing_directory > preproc_standard > scapptio113 > ephys`.
    - These files (`scapptio113_data.mat` and `scapptio113_info.mat`) go to Natasha.
15. **Run `run_an_experiment_time`:**
    - Directly modify the conflict file before running the script (e.g., for `'scapptio113'`). This can be done by creating a breakpoint at line 15.
    - Run the script.
16. **Run `run_sp_rejection`:**
    - Modify the conflict file for `'scapptio113'` in `...\your_preprocessing_directory\auxillary\experimental_timings\immediate_study_extended`.
    - Run the script.
    - Adjust reject for each muscle. Close the window and the next mode will load. Repeat this process (adjust reject > close window).


### Cascade and Surgical Studio data that was exported as EDF

- Open Cascade Classic / Surgical Studio
  - Export EDF+
    - Add an empty file to the EDF directory called `cascade` or `iomax`.
    - Add a file called `stim_delay.csv` that has the time until stim in a single record (e.g., `12ms` or `0ms`).
  - Note down the laminectomy time.
  - Export stacked EMG (under d-spinal view) [not for iomax].
    - [and match `augmented.xlsx` structure]
  - Export stacked d-waves.
    - [and match `rc.json` structure from other subjects]
  - Close Cascade Classic.
- When you export the EDF, make sure that (2020-10-08 16:13):
  - If it does not, you need to export stacked EMG again, but you have to disable the amplitude output and make it so that it's column-oriented.
  - This data should go into `...\data_stacked_emg_without_amplitude\...` that way it should get picked up by `run_sp_edf2mat.m` and converted into something that looks like the EDF+D output (and used automatically).
- Make a new folder `modik_` and set it in `dnc_set_env.m` (on all machines!), also change the name in encrypted `X:/` folder.
- Run the first part of `run_sp_edf2mat` (i.e., `sp_cascade_edf2mat`).
- Look in `data_deid_mat` folder for new patient ID (`P_...`).
- OCR step to recover amplitude:
  - Open Cascade Classic.
  - On a copy to be deleted of the cascade file.
  - Run `run_sp_get_stimamp_ocr` with this ID (follow instructions that get spit out when you run it).
  - In the `data_cascade_event_ss` folder, convert write to augment file (manually, watch out for `O` -> `0`).
  - *Note: the first decode is bad. This is by design.*
- Go back to `run_sp_edf2mat`, and run `sp_augment_events` with write on.
- In the `data_deid_mat` folder, convert `events_write` to `events_augment` (manually).
- And `run_sp_edf2mat` with the augment flag.
- Then run `run_sp_mat_aug_to_json`.

### EPWorks (xltek)

- Extract with `pyautogui` (see local readme/comments).
- Run `run_sp_epworks`.
