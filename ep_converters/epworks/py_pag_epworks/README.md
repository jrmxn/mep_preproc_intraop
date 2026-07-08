# Summary

Use PAG to extract time traces and stimulation amplitude from EP works case files.

## Steps to get this work

1) Open the case in EPWorks (review mode)
2) Make sure that you are viewing only one trace at the time
3) View -> Tests, delete all non relevant tests
4) Modify the properties of the timebar: uncheck the the box 'on next state...'
5) Figure out the approximate start of the experiment with pag.position(), and set that in the code
6) Make sure muscles match up...
7) Make sure the status bar is visible (otherwise the height is off)
8) Maximimse the main window AND the traces window, and set the division to 0.25 (see saved screenshot for example)
9) Run - make sure you do it from anaconda running as admin.
10) CSV files need to be zipped and placed, as do stimamp files (For processing in matlab)
## Usage

```python
import pyautogui as pag

# some future note
xy = pag.position()
```
