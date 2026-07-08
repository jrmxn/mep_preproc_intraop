import pyautogui as pag
import matplotlib.pyplot as plt
import numpy as np
from skimage import color
from skimage.feature import match_template
import os
from pathlib import Path
import time
DEBUG_COUNT = 0


def locate_core(im_ico, im_scr, th=0.8, reg=None):
    x = 0
    y = 0
    result = match_template(im_scr, im_ico)
    found = np.max(result)
    if found > th:
        ij = np.unravel_index(np.argmax(result), result.shape)
        x, y = ij[::-1]
        x = x + np.shape(im_ico)[1] / 2
        y = y + np.shape(im_ico)[0] / 2

        if reg:
            x = x + reg[0]
            y = y + reg[1]
        else:
            pass
    return x, y, found


def locate_load_ico(im, invert=False, debug=False):
    f = 'templates' + os.sep + im + '.png'
    im_ico = plt.imread(f)
    im_ico = color.rgb2gray(im_ico)

    if invert:
        im_ico = 1 - im_ico

    return im_ico


def locate_load_scr(reg=None, invert=False, debug=False):
    if reg:
        # at the moment this only works because...
        # my mask is from the top half of the screen (0,0,x,x)
        im_scr = pag.screenshot(region=reg)
        # crop it... no need to scan the whole image
        left, top, right, bottom = 0, 0, reg[2] - reg[0], reg[3] - reg[1]
        im_scr = im_scr.crop((left, top, right, bottom))
    else:
        im_scr = pag.screenshot()
    if debug:
        global DEBUG_COUNT
        im_scr.save(rf'dnc_debugging\x{DEBUG_COUNT}.tif')
        DEBUG_COUNT = DEBUG_COUNT + 1
    im_scr = np.asarray(im_scr)
    im_scr = color.rgb2gray(im_scr)
    if invert:
        im_scr = 1 - im_scr

    return im_scr


def locate(im, doclick=True, th=0.8, reg=None, invert=False, debug=False):
    im_ico = locate_load_ico(im, invert=invert, debug=debug)
    im_scr = locate_load_scr(reg=reg, invert=invert, debug=debug)
    x, y, found = locate_core(im_ico, im_scr, th=th, reg=reg)

    clicked = False
    if found > th:
        if doclick:
            pag.click(x, y, button='left')
            clicked = True

    return clicked, x, y, found


def movemousehome(sc, click=False):
    w = sc.width / 6
    h = sc.height - sc.height/10
    pag.moveTo(w, h)
    if click:
        pag.click()


if __name__ == '__main__':
    do_pag = True
    x_initial_location = 50
    x_initial_location = 2000
    dt_newframe = 4  # might need to be larger for longer experiments (since they load slower). 1s for normal should be fine.
    # x_initial_location = 400
    # you should (try to) put here the muscles that were actually recorded (i.e. if the labels are wrong in xltek)
    list_muscle_un = ['deltoid', 'bicep', 'tricep', 'apb', 'adm', 'ta', 'ahb']
    str_p = 'sub-xy'
    d_ephys = Path(f'C:/Users/jmcin/z/{str_p}/ephys_native')
    assert d_ephys.exists(), 'bad subject dir'
    d_stimamp = (d_ephys / f'{str_p}_stimamp')
    d_stimamp.mkdir(exist_ok=True)
    if do_pag:
        # dirpath = tempfile.mkdtemp()
        # # ... do stuff with dirpath
        # shutil.rmtree(dirpath)
        sc = pag.size()

        im = 'epworks'
        reg_bottom = (0, 250, sc.width, sc.height)
        locate(im, doclick=True, th=0.8, reg=reg_bottom)
        time.sleep(0.5)

        reg_muscle_strip = (0, 0, 250, sc.height)
        reg_response_window = (0, 0, 1100, sc.height-250)
        x_muscle_to_set = 2800

        do_invert = True
        im_scr = locate_load_scr(reg=reg_muscle_strip, invert=do_invert, debug=False)
        list_muscle = []
        list_muscle.extend(['l' + str_muscle for str_muscle in list_muscle_un])
        list_muscle.extend(['r' + str_muscle for str_muscle in list_muscle_un])

        # list_muscle = list_muscle[:6]  # debugging

        dict_muscle = dict.fromkeys(list_muscle)
        dict_muscle_export = dict.fromkeys(list_muscle)
        dict_muscle_properties = dict.fromkeys(list_muscle)

        do_identify_next_state = True
        if do_identify_next_state:
            im_ico = locate_load_ico('next_state', invert=do_invert, debug=False)
            x_next_state, y_next_state, found = locate_core(im_ico, im_scr, th=0.7)
            # n.b. this is hard-coded, because the search fails
            x_next_state = 2952
            y_next_state = 1925
            pag.moveTo(x_next_state, y_next_state, 1, pag.easeInCirc)

        do_identify_muscles = False
        if do_identify_muscles:
            # really you should split this: get all the coordinates first
            for muscle in list_muscle:
                im_ico = locate_load_ico(muscle, invert=do_invert, debug=False)
                x, y, found = locate_core(im_ico, im_scr, th=0.8, reg=reg_muscle_strip)
                dict_muscle[muscle] = [x, y]
                pag.moveTo(x, y)
                pag.click(button='left')
        else:
            # use known coordinates
            x = 25
            dict_muscle['ldeltoid'] = [30, 244 + x]
            dict_muscle['lbicep'] = [30, 323 + x]
            dict_muscle['ltricep'] = [30, 401 + x]
            dict_muscle['lapb'] = [30, 469 + x]
            dict_muscle['ladm'] = [30, 540 + x]
            dict_muscle['lta'] = [30, 610 + x]
            dict_muscle['lehl'] = [30, 610 + x]
            dict_muscle['lahb'] = [30, 681 + x]
            dict_muscle['rdeltoid'] = [30, 765 + x]
            dict_muscle['rbicep'] = [30, 833 + x]
            dict_muscle['rtricep'] = [30, 903 + x]
            dict_muscle['rapb'] = [30, 985 + x]
            dict_muscle['radm'] = [30, 1049 + x]
            dict_muscle['rta'] = [30, 1131 + x]
            dict_muscle['rehl'] = [30, 1131 + x]
            dict_muscle['rahb'] = [30, 1206 + x]

        # indentify_trigger_source = False
        do_identify_export_data = True
        if do_identify_export_data:
            for muscle in list_muscle:
                time.sleep(0.5)
                x, y = dict_muscle[muscle]
                pag.moveTo(x + x_muscle_to_set, y)
                pag.click(button='right')
                reg = (x_muscle_to_set - 200, 0, x_muscle_to_set + 400, sc.height)
                time.sleep(0.5)
                clicked, x, y, found = locate('export_data', doclick=False, th=0.8, reg=reg, debug=False)
                dict_muscle_export[muscle] = x, y
                pag.moveTo(x, y, duration=0.1)
                clicked, x, y, found = locate('properties', doclick=False, th=0.8, reg=reg, debug=False)
                dict_muscle_properties[muscle] = x, y
                pag.moveTo(x, y, duration=0.025)

                # if not indentify_trigger_source:
                #     pag.click()
                #     clicked, x, y, found = locate('str_trigger_source', doclick=False, th=0.8, reg=None)
                #     indentify_trigger_source = True  # do not repeat
                    # time.sleep(2.5)
                    # pag.press('escape')
                    # time.sleep(0.5)

                movemousehome(sc, click=True)

        do_reset_time = False
        if do_reset_time:
            im = 'time_arrow'
            clicked, x, y, found = locate(im, doclick=True, th=0.8, reg=reg_bottom)  # left, top, w, h
            time.sleep(0.5)
            x_target = 0
            pag.dragTo(x_target, y, duration=1 + np.abs(x-x_target)/400, tween=pag.easeOutQuad)
            time.sleep(0.25)
            clicked, x0_timeline, y0_timeline, found = locate(im, doclick=True, th=0.8, reg=reg_bottom)

        do_reset_time_custom = True
        if do_reset_time_custom:
            im = 'time_arrow'
            clicked, x, y, found = locate(im, doclick=True, th=0.8, reg=reg_bottom, debug=True)  # left, top, w, h
            time.sleep(2.5)
            x_target = x_initial_location
            pag.doubleClick(x_target, y)
            # pag.dragTo(x_target, y, duration=1 + np.abs(x-x_target)/400, tween=pag.easeOutQuad)
            # sometimes protektor32 just crashes here....
            # pag.moveTo(x_target + 10, y + 10, duration=0.2)
            # time.sleep(5)
            clicked, x0_timeline, y0_timeline, found = locate(im, doclick=True, th=0.8, reg=reg_bottom, debug=True)

        locate_by_next_state = True
        if locate_by_next_state:
            im_scr = locate_load_scr(reg=reg_response_window, debug=False)
            im_scr = np.zeros(np.shape(im_scr))
            sampling = True
            ix = 64
            ix_prev = -1
            vec_sampled = np.nan * np.zeros(sc.width)
            n_hist = 125
            scale = 1
            while sampling:
                # pag.moveTo(x0_timeline + ix, y0_timeline, duration=0.2)
                # pag.click(clicks=2)
                pag.click(x_next_state, y_next_state)
                movemousehome(sc, click=True)
                time.sleep(dt_newframe)
                im_scr_prev = im_scr
                im_scr = locate_load_scr(reg=reg_response_window, debug=False)
                screen_diff = np.mean(np.abs(im_scr - im_scr_prev))
                is_screen_diff = screen_diff > 0.001
                vec_sampled[ix] = is_screen_diff

                for muscle in list_muscle:
                    x, y = dict_muscle[muscle]
                    pag.click(x + x_muscle_to_set, y, button='right')
                    time.sleep(0.2)
                    x, y = dict_muscle_export[muscle]
                    pag.click(x, y, duration=0.2)
                    movemousehome(sc, click=True)

                    if muscle == list_muscle[0]:
                        # something is going wrong somewhere in this if
                        x, y = dict_muscle[muscle]
                        pag.click(x + x_muscle_to_set, y, button='right')
                        time.sleep(0.25)
                        x, y = dict_muscle_properties[muscle]
                        pag.click(x, y, duration=0.2)
                        time.sleep(1.25)
                        reg = (sc[0]/2 - 670/2, sc[1]/2 - 700/2, 670, 700)    # center
                        im_scr_prop = pag.screenshot(region=reg)
                        p_out = d_stimamp / rf'x{ix:05d}.tif'
                        im_scr_prop.save(p_out)
                        time.sleep(1.25)
                        pag.press('escape')
                        movemousehome(sc, click=True)

                if np.all(vec_sampled[ix+1-n_hist:ix+1] == 0) and ix >= n_hist:
                    sampling = False
                    print('ending sampling')

                ix = ix + 1

            locate('pycharm', doclick=True, th=0.8, reg=reg_bottom)

        locate_by_difference = False
        if locate_by_difference:
            im_scr = locate_load_scr(reg=reg_response_window, debug=False)
            im_scr = np.zeros(np.shape(im_scr))
            sampling = True
            ix = 0
            ix_prev = -1
            vec_sampled = np.nan * np.zeros(sc.width)
            n_hist = 25
            scale = 1
            while sampling:
                pag.moveTo(x0_timeline + ix, y0_timeline, duration=0.2)
                pag.click(clicks=2)

                movemousehome(sc, click=True)
                time.sleep(0.75)
                im_scr_prev = im_scr
                im_scr = locate_load_scr(reg=reg_response_window, debug=False)
                screen_diff = np.mean(np.abs(im_scr - im_scr_prev))
                is_screen_diff = screen_diff > 0.001
                vec_sampled[ix] = is_screen_diff

                if is_screen_diff and scale == 1:
                    for muscle in list_muscle:
                        x, y = dict_muscle[muscle]
                        pag.click(x + x_muscle_to_set, y, button='right')
                        time.sleep(0.1)
                        x, y = dict_muscle_export[muscle]
                        pag.click(x, y, duration=0.2)
                        movemousehome(sc, click=True)

                        if muscle == list_muscle[0]:
                            # something is going wrong somewhere in this if
                            x, y = dict_muscle[muscle]
                            pag.click(x + x_muscle_to_set, y, button='right')
                            time.sleep(0.1)
                            x, y = dict_muscle_properties[muscle]
                            pag.click(x, y, duration=0.2)
                            time.sleep(0.75)
                            im_scr_prop = pag.screenshot(region=reg)
                            im_scr_prop.save(rf'dnc_stimamp\x{ix:05d}.tif')
                            time.sleep(0.75)
                            pag.press('escape')
                            movemousehome(sc, click=True)
                elif ix >= sc.width - n_hist:
                    scale = 1
                elif is_screen_diff and not scale == 1:
                    # we hit a change after a jump so go back and reduce step size
                    scale = 1
                    ix = ix_prev
                elif np.all(vec_sampled[ix+1-n_hist:ix+1] == 0) and ix >= n_hist:
                    scale = n_hist

                ix_prev = ix
                ix = ix + scale

                if scale == 1 and ix >= sc.width:
                    sampling = False
                    print('ending sampling')

                print(ix, ix_prev)

            # plt.plot(vec_sampled)
            locate('pycharm', doclick=True, th=0.8, reg=reg_bottom)

    print('Done! - zip stimamp and csv files and place them in matlab accessible location.')
