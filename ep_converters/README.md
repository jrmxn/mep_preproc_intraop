# Introduction

**Author:** J R McIntosh

> **Note:** Surgical Studio is for JSON files only. `cascade_classic` handles both Surgical Studio and Cascade Classic EDF formats.

## Surgical Studio (JSON) Workflow

This README is primarily focused on processing **Surgical Studio JSON exports**, which is the current preferred and standard method. The following is an example workflow for a specific participant (e.g., Participant 113):

1. Create a new participant folder within your `D_DATA` directory. The structure and naming convention must closely match the template provided in this repository under `ep_converters/surgical_studio/template_participant_folder/`. A completed structure looks like this:
   ```text
   [participant_prefix][participant_id]/
   └── [unique_redcap_id]_[participant_prefix][participant_id]  # <- this is a file that links the two id types, it should have no content.
   └── ephys/
       └── cadwell-iomax/
           ├── [participant_prefix][participant_id]_data.json
           ├── [participant_prefix][participant_id]_events_augment.xlsx
           └── [participant_prefix][participant_id]_properties.toml
   ```
   *Note: A properties TOML file (e.g., `scapptio113_properties.toml`) is required to exist here alongside the data. It contains crucial metadata like `sweep_info` and `peripheral_config`.*
2. Export the main data `.json` file from Surgical Studio in the form of case data. Save it as `[participant_prefix][participant_id]_data.json` inside the `ephys/cadwell-iomax/` folder.
3. In MATLAB, go to mep_preproc_intraop > ep_converters > Surgical studio > run_sp_surgical_studio_augment`.
4. Run the script.
5. Edit the configuration in a text editor to match this structure (if needed):

   ```json
   {
       "main_conditions": [
           {
               "enabled": true,
               "augment_op": "write",
               "overwrite": true,
               "participant_ix": [113],
               "participant_prefix": "scapptio",
               "data_directory": "D_DATA"
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
8. The excel file `scapptio113_events_write` will populate here. Rename it to `scapptio113_events_augment`. This is what MATLAB will load back in.
9. Open `scapptio113_events_augment` (it is an Excel file you will edit).
10. Add in the level, laterality, electrode type, orientation, stimulation type, and approach. Refer to the **Events Augmentation Guidelines** section below for details on exactly what information to add to the respective columns of the spreadsheet based on the experimental condition.
11. (Optional) Create, edit, or delete the exceptions file (`scapptio113_exceptions.json`) in the same folder if any mode reassignments are necessary. See the [Exception Files](#exception-files) section below for formatting details.
12. Change your configuration JSON to use the `"augment"` operation and save:

    ```json
    {
        "main_conditions": [
            {
                "enabled": true,
                "augment_op": "augment",
                "overwrite": true,
                "participant_ix": [113],
                "participant_prefix": "scapptio",
                "data_directory": "D_DATA"
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

13. Close the Excel file and then run `run_sp_surgical_studio_augment.m` again.
14. Add the participant to the study list as directed (e.g., `scap 113 = 74`).
15. Check the README.md one level up once the participant has been added to the study list.


## Events Augmentation Guidelines

When editing the `[participant]_events_augment.xlsx` file in step 10, fill in specific columns based on the type of data or experimental condition. The table below outlines the types of conditions (Description) and what you should put into the corresponding columns (`set_sequence`, `set_group`, `cx_pct`, `sc_pct`, `moi`, and `muscle_targeted`). 

*Note: If `cx_pct` (cortical percentage) or `sc_pct` (spinal cord percentage) are unknown for a given row, you can set them to `-1`.*

| Description | `set_sequence` | `set_group` | `cx_pct` | `sc_pct` | `moi` | `muscle_targeted` |
| --- | --- | --- | --- | --- | --- | --- |
| **Standard paired average** | `pa-001` | `Gpa-001` | `110, (if unknown, set to -1)` | `110, (if unknown, set to -1)` | `["Triceps", "Biceps", "ECR", "FCR", "APB", "ADM"]` | `ECR` |
| **Pairing** | `e.g. scap_pre-001, e.g. scap-001, e.g. scap_post-001` | `gscap-001` | `110, (or -1 e.g. if intervention is sub cx)` | `90, (or 110, or -1 etc)` | | |
| **Ramp** | `cxramp-001` | `gcxramp-001` | `e.g. -1 (if ramping brain)` | `110` | | |
| **Multipulse** | `-not sure what this convention is-` | `-should search the folders for 'multipulse' or 'multi pulse' (but n.b. it's in xlsx files)` | | | `["Triceps", "Biceps", "ECR", "FCR", "APB", "ADM"]` | `APB` |
| **Peripheral pairing average to median** | `pma-001` | `gpma-001` | `110` | `90` | | |
| **To ulnar** | `pmu-001` | | | | | |
| **Peripheral (for CDMRP)** | | `peripheral` | | | | |
| **Probe** | `probe` | `spatial` | | | | |
| **Spatial CDMRP condition** | `e.g. M04N` | `spatial` | | | | |
| **Frequency CDMRP condition** | `e.g. B03PO02, e.g. B03F01` | `frequency` | | | | |
| **Pulsewidth CDMRP conditon** | `e.g. B03PW01` | `pulsewidth` | | | | |
| **xray** | | `xray` | | | | |

## Exception Files

Exception files are currently used primarily for Surgical Studio JSON exports to handle necessary mode reassignments or data corrections before processing.

The exception file should be named according to the participant prefix and ID, e.g., `<participant_prefix><participant_id>_exceptions.json` (such as `scapptio113_exceptions.json`). It should be placed in the same device directory as the data and events files (e.g., `.../ephys/cadwell-iomax/`).

### Available Exception Types

The JSON structure allows for several types of exceptions to handle various edge cases and data corrections:

#### 1. `mode_reassign`
Moves trials from one mode to another based on matching stimuli names. You can optionally delete the original mode entirely.
```json
{
  "mode_reassign": {
    "delete_original": "Name of the mode to delete entirely (optional)",
    "from": "Source mode name to extract trials from",
    "if_contains_stimuli": "Name of the stimuli to look for",
    "to": "Destination mode name for the extracted trials"
  }
}
```

**Example:**
If you need to reassign trials containing the stimuli `"Research D-Wave"` from a generic `"MEP"` mode to a new `"Research D-Wave"` mode, your exceptions file would look like this:
```json
{
  "mode_reassign": {
    "from": "MEP",
    "if_contains_stimuli": "Research D-Wave",
    "to": "Research D-Wave"
  }
}
```

#### 2. `channel_reassign`
Renames channels. You can optionally provide `channel_reassign_after` (a time string, e.g., `"10:00:00"`) to only rename channels after a specific time on the recording day. Space characters in original names should be preserved.
```json
{
  "channel_reassign_after": "10:00:00",
  "channel_reassign": {
    "OldChannelName": "NewChannelName",
    "Old Channel_0x20_Name": "NewChannelName"
  }
}
```

#### 3. `invert_cortical_stimulation`
A boolean flag (`true`/`false`). If set to true, flips the annotated side of cortical stimulation (e.g., Left becomes Right) and swaps the anode/cathode mappings for the outputs.
```json
{
  "invert_cortical_stimulation": true
}
```

#### 4. `tes_is_hardware_quad`
A boolean flag (`true`/`false`). Used when a hardware splitter was utilized for quad stimulation instead of configuring it in the IOMAX software. It overrides software "bipolar" settings to "quad" and injects the additional hardware outputs (`H3`, `H4`) into the trace data.
```json
{
  "tes_is_hardware_quad": true
}
```

#### 5. `sweep`
Corrects erroneous sweep parameters setup during early digitimer usage (specifically for `research_paired_repeat_trigger`). 
```json
{
  "sweep": {
    "research_paired_repeat_trigger": {
      "sweep": 50,
      "sweep_delay": 5
    }
  }
}
```

#### 6. `DataSweepTriggerDelayCustom`
Provides custom adjustments for the trigger delay (typically used for specific participant edge cases like `cdmrp003`). Handled internally by auxiliary functions.
```json
{
  "DataSweepTriggerDelayCustom": {
    "...": "..."
  }
}
```

## Legacy Export Methods

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
