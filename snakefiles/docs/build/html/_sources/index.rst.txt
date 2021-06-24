.. test_documentation documentation master file, created by
   sphinx-quickstart on Wed Apr 28 13:36:16 2021.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Welcome to TypeSeq2 documentation!
==============================================


NCI CGR laboratory HPV typing analysis workflows and R package

TypeSeq HPV is an R package that includes

several helper functions for working with TypeSeq data
contains a "make" based pipeline for processing Ion or Illumina runs
contains a docker build file that includes all the dependencies inside a single container
We recommend running the pipeline inside the docker container cgrlab/typeseqhpv:final_2018080604 as it contains all the required dependencies in the correct locations.

The workflow manager we use is drake https://github.com/ropensci/drake

There are currently two main workflows each supporting either the Ion Torrent or Illumina NGS platforms. Since TypeSeqHPV can be used on either platform we therefore have analysis for either.

The only requirement for either workflow is either docker or singularity




.. _main=Installation:


.. toctree::
   :caption: Installation
   :maxdepth: 1

   
   Installation/requirements
   Installation/source_code
   Installation/GUI
   Input_files/input.rst
   troubleshooting/troubleshooting.rst 
   Instrument/S5s.rst


Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
