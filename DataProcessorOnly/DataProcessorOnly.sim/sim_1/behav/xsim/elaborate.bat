@echo off
REM ****************************************************************************
REM Vivado (TM) v2023.2 (64-bit)
REM
REM Filename    : elaborate.bat
REM Simulator   : AMD Vivado Simulator
REM Description : Script for elaborating the compiled design
REM
<<<<<<< HEAD
REM Generated by Vivado on Sun Apr 21 21:30:48 +0100 2024
=======
REM Generated by Vivado on Mon Apr 22 11:50:58 +0100 2024
>>>>>>> 673e012e686b30a6319c3eab34af8695a3397105
REM SW Build 4029153 on Fri Oct 13 20:14:34 MDT 2023
REM
REM Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
REM Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
REM
REM usage: elaborate.bat
REM
REM ****************************************************************************
REM elaborate design
echo "xelab --incr --debug typical --relax --mt 2 -L xil_defaultlib -L secureip --snapshot tb_dataGenConsume_behav xil_defaultlib.tb_dataGenConsume -log elaborate.log"
call xelab  --incr --debug typical --relax --mt 2 -L xil_defaultlib -L secureip --snapshot tb_dataGenConsume_behav xil_defaultlib.tb_dataGenConsume -log elaborate.log
if "%errorlevel%"=="0" goto SUCCESS
if "%errorlevel%"=="1" goto END
:END
exit 1
:SUCCESS
exit 0