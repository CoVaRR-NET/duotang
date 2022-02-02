#!/usr/bin/env python3
import os
from os import path
import sys
import csv

import numpy as np
import pandas as pd


from functools import reduce
import math

#graphic libraries
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.cm import hsv
from matplotlib.lines import Line2D
import seaborn as sns
sns.set_theme(style="ticks", color_codes=True)


def autolabel(ax,x,text,textcolor):
    ax.text(x, 50, text, color=textcolor,ha='center', va='center', rotation=90,weight="bold")
    
#dictionnary to label each mutation
nucsub_AAname = {}
def load_mut_names(file):
    for i,(nuc,AA) in pd.read_csv(file,sep="\t",header=None).iterrows():
        if AA[0] == AA[-1]: AA="" # do not name synonymous mutations
        nucsub_AAname[nuc]=AA


min_val_AAlabel=10 # % of alt alleles to add amino acide label
def def_min_val_label(n):
    global min_val_AAlabel
    min_val_AAlabel=n
        
#colors of the different mutations
label_color = {'A>C': 'gold',
               'A>G': 'silver',
               'A>T': 'mediumpurple',
               'C>A': 'limegreen',
               'C>G': 'violet' ,
               'C>T': 'dodgerblue',
               'G>A': 'mediumblue',
               'G>C': 'fuchsia',
               'G>T': 'forestgreen',
               'T>A': 'indigo',
               'T>C': 'dimgrey',
               'T>G': 'darkorange',
               'missing': 'black'}

genes={}
genes[266]=('ORF1ab',21555)
genes[21563]=('Spike',25384)
genes[25393]=('ORF3a',26220)
genes[26245]=('E',26472)
genes[26523]=('M',27191)
genes[27202]=('ORF6',27387)
genes[27394]=('ORF7a',27759)
genes[27756]=('ORF7b',27887)
genes[27894]=('ORF8',28259)
genes[28274]=('N',29533)
genes[29558]=('ORF10',29674)

def addgenenames(ax, x_names):
    n_pos=len(x_names)
    ax.set(yticks=[25,50,75])
    ax.set_ylabel("gene\nnames",  fontsize=20)
    ax.set_ylim((0,100))
    ax.margins(0, 0)  
    colcol="grey"
    for lower_bound in genes.keys():
        (gene_name,upper_bound)=genes[lower_bound]
        pospos=[i for i in x_names.keys() if (i>lower_bound and i<upper_bound)]
        if pospos!=[]:
            span=[(i in pospos)*100 for i in x_names.keys()]
            ax.bar(x_names , span , bottom=[0]*n_pos , color=colcol , edgecolor="none" , width=1)
            if colcol=="grey": colcol="black"
            else             :  colcol="grey"
            mean=0
            for i in range(n_pos):
                if list(x_names.keys())[i] in pospos:
                    mean+=i/len(pospos)
            mean=int(mean)
            autolabel(ax,mean,gene_name,"white")
            
#Create a list of panda table containing all the numbers for each of the 29903 positions
def openfiles(inputfiles):
    tablelist=[]
    for file in inputfiles:
        if path.exists(file):
            t=pd.read_csv(file,sep="\t")
            n_sample=sum(t.iloc[0][["A","C","G","T","."]])
            if(n_sample==0):
                print("NO SAMPLE IN FILE : "+file)
                return None;
            tablelist.append(t)
        else:
            print("ERROR NO SUCH FILE : "+file)
            return None;
    return tablelist

#Loop through the tables and keep only the positions wher an alternative allele represent
# more than min% of the total number of samples
def getpositions(tablelist,percentmin=0,addmissing=False):
    totalposlist=[]
    for t in tablelist:
        #absolute minimum number of sample
        n_min=math.ceil(percentmin/100*sum(t.iloc[0][["A","C","G","T","."]]))
        # for each possible reference allele :
        totalposlist+=list(t[(t["REF"]=="A") & ((t["C"]>=n_min) | (t["G"]>=n_min) | (t["T"]>=n_min))].index)
        totalposlist+=list(t[(t["REF"]=="C") & ((t["A"]>=n_min) | (t["G"]>=n_min) | (t["T"]>=n_min))].index)
        totalposlist+=list(t[(t["REF"]=="G") & ((t["C"]>=n_min) | (t["A"]>=n_min) | (t["T"]>=n_min))].index)
        totalposlist+=list(t[(t["REF"]=="T") & ((t["C"]>=n_min) | (t["G"]>=n_min) | (t["A"]>=n_min))].index)
        if addmissing:
            totalposlist+=list(t[t["."]>=n_min].index)
    totalposlist=np.unique(totalposlist)
    totalposlist.sort()
    return totalposlist
    


def bighist(tablelist,poslist,y_names,mytitle="",suptables=[],PDFname=""):
    
    fig = plt.figure(figsize=(len(poslist)/3+6,2*(len(tablelist)+len(suptables)+2)), constrained_layout=False)
    #print(len(tablelist)+len(suptables)+1)
    gs = fig.add_gridspec(nrows=len(tablelist)+len(suptables)+1, ncols=1, hspace=0)
    ax = gs.subplots(sharex=True)
    x_names=(tablelist[0].iloc[poslist]["POS"].astype(str))
    for i in range(len(suptables)):
        ax[i].bar(x_names , suptables[i] , bottom=[0]*len(poslist) , color="grey" , edgecolor="none" , width=1)
    for i in range(len(tablelist)):
        axx=ax[i+len(suptables)]
        #print(i)
        nb_sample=sum(tablelist[i].iloc[0][["A","C","G","T","."]])
        if nb_sample<10000:
            str_nb_sample="\nn="+str(nb_sample)+""
        else:
            str_nb_sample="\nn="+str(int(nb_sample/1000))+"K"
        axx.set(yticks=[25,50,75])
        axx.set_ylabel(y_names[i]+str_nb_sample,  fontsize=18)
        axx.set_ylim((0,100))
        axx.margins(0, 0)  
        all_pos_toplot=tablelist[i].iloc[poslist]
        all_bottoms=all_pos_toplot['A']-all_pos_toplot['A']
        missingvalues=all_pos_toplot["."]/nb_sample*100
        axx.bar(x_names, missingvalues, bottom=all_bottoms, color="black",edgecolor="none",width=1)
        all_bottoms+=missingvalues
        #loop in all the 12 combinaisons:
        for ref in ["A","C","G","T"]:
            for alt in [a for a in ["A","C","G","T"] if a!=ref]:
                values=all_pos_toplot[alt].copy()
                #set to 0 the alt numbers for the others ref alleles
                values[all_pos_toplot['REF'] != ref] = 0 
                values=values/nb_sample*100
                if sum(values)>0 :
                    col=label_color[ref+">"+alt]
                    axx.bar(x_names, values,bottom=all_bottoms,color=col,edgecolor="none",width=1)
                    for j in range(len(values)):
                        if values.iloc[j]>min_val_AAlabel:
                            pos=all_pos_toplot.iloc[j]["POS"]
                            idx=pos.astype(str)+ref+">"+alt
                            if idx in nucsub_AAname:
                                textcolor="black"
                                if ref+">"+alt in ["T>A","G>A","T>C"]:
                                    textcolor="lightgrey"
                                autolabel(axx,j,nucsub_AAname[idx],textcolor)
                    all_bottoms+=values
    ax_last=ax[len(tablelist)+len(suptables)]
    addgenenames(ax_last,x_names)
    ax_last.tick_params(axis='x',bottom=True,labelrotation=90, labelsize=20)
    legend=[]
    for l in label_color:
        ltu=l.replace("T","U")
        legend.append(mpatches.Patch(color=label_color[l], label=ltu))
    fig.legend(handles=legend,loc='center right',title=mytitle, bbox_to_anchor=(1.05, 0.5))
    fig.subplots_adjust(right=0.9)
    if PDFname!="":
        fig.savefig(PDFname, bbox_inches='tight')
        
        
def createsuptable(positions,filename, colname):
    t=pd.read_csv(filename,sep="\t")
    return t[t['pos_in_genome'].isin(positions)][colname]
