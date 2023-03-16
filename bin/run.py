#%%
import os
import sys

sys.path.append('/')

import collections.abc
import itertools
import json
from glob import glob
from os import path

import bids
import nibabel as nib
from nibabel.funcs import four_to_three
import numpy as np
from PRFclass import PRF
from matplotlib import pyplot as plt

# get all needed functions
flywheelBase = '/flywheel/v0'
sys.path.insert(0, flywheelBase)

configFile = path.join(flywheelBase, 'config.json')

# updates nested dicts
def update(d, u):
    for k, v in u.items():
        if isinstance(v, collections.abc.Mapping):
            d[k] = update(d.get(k, {}), v)
        else:
            d[k] = v
    return d


# turns a list within a string to a list of strings
def listFromStr(s):
    return s.split(']')[0].split('[')[-1].split(',')


#  turns the config entry to a loopable list
def config2list(c, b=None):
    if b is not None:
        if 'all' in c:
            l = b
        else:
            if isinstance(c, list):
                l = c
            else:
                l = listFromStr(c)
    else:
        if isinstance(c, str):
            try:
                l = [float(a) for a in listFromStr(c)]
            except:
                l = listFromStr(c)
        elif isinstance(c, list):
            if isinstance(c[0], list):
                l = c
            else:
                try:
                    l = [float(a) for a in c]
                except:
                    l = c
        elif isinstance(c, float) or isinstance(c, bool) or isinstance(c, int):
            l = [c]

    l.sort()

    return l


################################################
# define de default config
defaultConfig = {
 	'subjects' : ['all'],
 	'sessions' : ['all'],
 	'tasks'    : ['all'],
 	'runs'     : ['all'],
    'prfanalyzeAnalysis': '01',
    'masks' : {
     	'rois'     : [['V1']],
     	'atlases'  : ['benson'],
        'varianceExplained' : [0.1],
        'eccentricity' : False,
        'beta' : False,
    },
 	'coveragePlot' : {
     	'create' : True,
        'method' : ['max'],
        'minColorBar' : [0],
 	},
    'cortexPlot' : {
         'createCortex' : True,
         'createGIF'    : True,
         'parameter'    : ['ecc'],
         'hemisphere'   : 'both',
         'surface'      : ['sphere'],
         'showBordersArea'  : ['V1'],
    },
    'saveAs3D': True,
    'verbose' : True,
    'force'   : False,
}


def die(*args):
    print(*args)
    sys.exit(1)

################################################
# load in the config json and update the config dict
try:
    with open(configFile, 'r') as fl:
        jsonConfig = json.load(fl)
    config = update(defaultConfig, jsonConfig)

except Exception:
    with open(path.join(flywheelBase, 'config.json'), 'w') as fl:
        json.dump(defaultConfig, fl, indent=4)
    print('Could not read config.json!')
    die('Dumped the default config.')

verbose = config['verbose']
force = config['force']

def note(*args):
    if verbose:
        print(*args)
    return None

note('Following configuration is used:')
note(json.dumps(config, indent=4))

# find all mask combinations
allMaskCombs = list(itertools.product(
                    config2list(config['masks']['rois']),
                    config2list(config['masks']['atlases']),
                    config2list(config['masks']['varianceExplained']),
                    config2list(config['masks']['eccentricity']),
                    config2list(config['masks']['beta']),
                    ))

# find all coverage map parameter combinations defined
covMapParamsCombs = list(itertools.product(
                    config2list(config['coveragePlot']['method']),
                    config2list(config['coveragePlot']['minColorBar']),
                    ))

cortexParamsCombs = list(itertools.product(
                    config2list(config['cortexPlot']['parameter']),
                    config2list(config['cortexPlot']['hemisphere']),
                    config2list(config['cortexPlot']['surface']),
                    ))

print()

################################################
# set specified prfprepare analyses
prfanalyzeAnalysis = config['prfanalyzeAnalysis']
prfanalyzeP = path.join(flywheelBase, 'data', 'derivatives',
                        'prfanalyze-vista', f'analysis-{prfanalyzeAnalysis}')
# read the options.json
with open(path.join(prfanalyzeP, 'options.json'), 'r') as fl:
    prfanalyzeConfig = json.load(fl)

prfprepareAnalysis = prfanalyzeConfig['prfprepareAnalysis']
prfprepareP = path.join(flywheelBase, 'data', 'derivatives',
                        'prfprepare', f'analysis-{prfprepareAnalysis}')

# read the options.json
with open(path.join(prfprepareP, 'options.json'), 'r') as fl:
    prfprepareConfig = json.load(fl)

analysisSpace = prfprepareConfig['analysisSpace']

# get the BIDS layout
layout = bids.BIDSLayout(prfprepareP)

# subject from config and check
BIDSsubs = layout.get_subjects()
subs = config2list(config['subjects'], BIDSsubs)

################################################
# loop over subjects
for subI,sub in enumerate(subs):

    # close all open figures
    plt.close('all')

    if sub not in BIDSsubs:
        die(f'We did not find given subject {sub} in BIDS dir!')

    # session if given otherwise it will loop through sessions from BIDS
    BIDSsess = layout.get_session(subject=sub)
    sess = config2list(config['sessions'], BIDSsess)

################################################
# loop over sessions
    for sesI, ses in enumerate(sess):

        if ses not in BIDSsess:
            die(f'We did not find given session {ses} in subject {sub}!')
        else:
            note(f'Working: sub-{sub} ses-{ses}...')

        # find all tasks when given, else all tasks
        BIDStasks = layout.get_task(subject=sub, session=ses)
        tasks = config2list(config['tasks'], BIDStasks)

################################################
# loop over tasks
        for taskI, task in enumerate(tasks):
            # find all runs when given, else all runs
            BIDSruns = layout.get_run(subject=sub, session=ses, task=task)
            runs = config2list(config['runs'], BIDSruns)
            runs = [r if len(str(r)) < 4 else f'{r}avg' for r in runs]

################################################
# loop over runs
            for runI,run in enumerate(runs):
                try:
                    # now load the analysis
                    ana = PRF.from_docker(study   = 'data',
                                          subject = sub,
                                          session = ses,
                                          task    = task,
                                          run     = run,
                                          method  = 'vista',
                                          analysis = prfanalyzeAnalysis,
                                          hemi    = '',
                                          baseP   = flywheelBase,
                                          orientation = 'VF'
                                          )
                except:
                    continue

################################################
# apply all masks
                for roi,atlas,varExpThresh,eccThresh,betaThresh in allMaskCombs:

                    ana.maskROI(area  = roi,
                                atlas = atlas)

                    ana.maskVarExp(varExpThresh = varExpThresh)

                    if eccThresh:
                        ana.maskEcc(rad = eccThresh)

                    if betaThresh:
                        ana.maskBetaThresh(betaMax = betaThresh)

################################################
# save the result files back to volumes
                if analysisSpace == 'volume' and config['saveAs3D']:
                    outFpath = path.join(flywheelBase, 'data', 'derivatives',
                                         'prfresult', f'analysis-{prfanalyzeAnalysis}',
                                         'volumeResults', f'sub-{sub}', f'ses-{ses}')
                    os.makedirs(outFpath, exist_ok=True)

                    dummyFile = nib.load(glob(path.join(flywheelBase, 'data', 'derivatives', 'fmriprep',
                                                f'analysis-{prfprepareConfig["fmriprep_analysis"]}',
                                                f'sub-{sub}', f'ses-{ses}', 'func',
                                                '*desc-preproc_bold.nii*'))[0])

                    img = four_to_three(dummyFile)[0]

                    ana.loadTC()

                    for param in ['x0', 'y0', 's0', 'r0', 'phi0', 'varexp0', 'mask']:#, 'voxelTC0'
                        if param == 'mask':
                            outFname = ana._get_surfaceSavePath(param, 'BOTH', 'results', plain=False)
                        else:
                            outFname = ana._get_surfaceSavePath(param, 'BOTH', 'results', plain=True)

                        outF = path.join(outFpath, outFname[1]+'.nii.gz')
                        if not path.isfile(outF) or force:

                            if param == 'voxelTC0':
                                dat = np.zeros(dummyFile.shape)
                            else:
                                dat = np.zeros(img.shape)

                            for pos, boldI in zip(ana._roiIndOrig, ana._roiIndBold):
                                dat[tuple(pos)] = getattr(ana, param)[boldI]

                            newNii = nib.Nifti1Image(dat, header=img.header, affine=img.affine)
                            nib.save(newNii, outF)

################################################
# finally cretate Coverage plots
                if config['coveragePlot']['create']:

                    for method, minColbar, in covMapParamsCombs:

                        ana.plot_covMap(method  = method,
                                        cmapMin = minColbar,
                                        show    = False,
                                        save    = True,
                                        force   = force,
                                        )


################################################
# cretate the cortex gif plots
                if config['cortexPlot']['createCortex']:
                    if analysisSpace == 'volume':
                        print('We can not yet plot volume data to surface!')
                        continue

                    for param, hemi, surface in cortexParamsCombs:

                        ana.plot_toSurface(param = param,
                                            hemi  = hemi,
                                            save  = True,
                                            fmriprepAna      = prfprepareConfig['fmriprep_analysis'],
                                            forceNewPosition = False,
                                            surface     = surface,
                                            showBordersAtlas = 'all',
                                            showBordersArea  = config['cortexPlot']['showBordersArea'],
                                            interactive = False,
                                            create_gif  = config['cortexPlot']['createGIF'],
                                            headless    = True,
                                            )
