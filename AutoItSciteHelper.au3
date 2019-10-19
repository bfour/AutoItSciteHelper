#cs

   Copyright 2010-2017 Florian Pollak (bfourdev@gmail.com

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

#ce

#include <File.au3>
#include <Array.au3>
#include <GUIConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#Include <String.au3>
#include <_stringReplaceVariables.au3>
#include <Misc.au3>
#include <_gridDir.au3>
#include <_config.au3>
#include <_FPUI.au3>

$_FPUIShowLevel = 0 ; 0 .. debug, 1 .. info ...
$_FPUIUseQUIDefault = 0
$_FPUIUseConsoleDefault = 1

Opt("WinTitleMatchMode",2)
AutoItSetOption("GUIOnEventMode",1)

Global $autoItDir=_stringReplaceVariables(_iniRead($globalConfigPath,"systemIntegration","autoItDir",@ProgramFilesDir&"\AutoIt3"))
Global $includeRecursionMemory[1]

Run($autoItDir&"\SciTe\SciTE.exe "&$CmdLineRaw)

If _Singleton(@ScriptName,1) == 0 Then Exit

WinWait(" SciTE-Lite","")
$zerocycle=0
$onecycle=0
While WinExists(" SciTE-Lite","")==1
   If WinActive(" SciTE-Lite","")==0 And $zerocycle==0 Then
      $zerocycle=1
      $onecycle=0
      HotKeySet("^{F8}")
      HotKeySet("^{F9}")
      HotKeySet("^!a")
      HotKeySet("^!y")
   ElseIf WinActive(" SciTE-Lite","")<>0 And $onecycle==0 Then
      $zerocycle=0
      $onecycle=1
      HotKeySet("^{F8}","compile")
      HotKeySet("^{F9}","_pack")
      HotKeySet("^!a","zoomin")
      HotKeySet("^!y","zoomout")
   EndIf
   Sleep(900)
WEnd

Func _getCurrentFile()
   Beep(1500,100)
   ControlSend("SciTE-Lite","","[CLASS:ToolbarWindow32; INSTANCE:1]","^s")
   $currenttitle=WinGetTitle(" SciTE-Lite","")
   $currentpath=StringLeft($currenttitle,StringInStr($currenttitle," - SciTE-Lite")-1)
   $currentscriptname=StringSplit($currentpath,"\")
   $currentscriptname=$currentscriptname[$currentscriptname[0]]
   $currentfolder=StringTrimRight($currentpath,StringLen($currentscriptname)+1)
   Local $ret[3] = [$currentfolder, $currentscriptname, $currenttitle]
   Return $ret
EndFunc

Func compile()

   Local $ret = _getCurrentFile()
   Local $currentfolder = $ret[0]
   Local $currentscriptname = $ret[1]
   Local $currentPath = $currentfolder&"\"&$currentscriptname
   Local $currenttitle = $ret[2]

   If FileExists($currentfolder&"\icon.ico") Then
      $currenticon=$currentfolder&"\icon.ico"
   Else
      $currenticon=@ScriptDir&"\data\defaulticon.ico"
   EndIf
   $currentoutputpath=$currentfolder&"\"&StringTrimRight($currentscriptname,3)&"exe"

   If StringInStr($currenttitle,"(Untitled) ")==0 Then

      Local $PID = Run($autoItDir&'\Aut2Exe\Aut2exe.exe /in "'&$currentpath&'" /out "'&$currentoutputpath&'" /icon "'&$currenticon&'"')
      _FPUITask("compiling "&$currentpath, $PID)
      ProcessWaitClose($PID,86)
      Beep(500,100)
      _FPUITaskDone("compiler finished", $PID)

   Else
      _FPUITaskDone()
   EndIf

EndFunc

Func _pack()

   Local $ret = _getCurrentFile()
   Local $currentFolder = $ret[0]
   Local $currentscriptname = $ret[1]
   Local $currentPath = $currentfolder&"\"&$currentscriptname
   Local $includesOutputFolder = $currentFolder&"\includes"

   DirCreate($includesOutputFolder)

   _FPUITask("packing "&$currentPath)
   _copyIncludesToFolder($currentPath, $includesOutputFolder)
   _FPUITaskDone("packing finished")

EndFunc

Func _copyIncludesToFolder($au3File, $folder)

   ; read includes
   Local $line = 1
   Local $pragmaPattern = '(?i)\#include ([<"])(.*)[>"]'

   ; go through all lines of file
   While 1

      Local $lineStr = FileReadLine($au3File, $line)
	  If @error == -1 Then ExitLoop ; EOF
      If @error ==  1 Then
         _error("FileReadLine #"&$line&" for "&$au3File&" failed")
         ExitLoop
      EndIf
      $line += 1

      ; check if this line is an include-pragma
      Local $matches = StringRegExp($lineStr, $pragmaPattern, 1)
      If UBound($matches)<>2 Then ContinueLoop

      ; at this point we have a working regex match for a pragma include
      ; copy the referenced file and recurse into this file
      Local $prefix = $matches[0]
      Local $pragmaFile = $matches[1]
      _FPUIDebug("processing pragma file "&$pragmaFile)
      If $prefix == "<" Then ; include from include-folder
         Local $absolutePath = $autoItDir&"\Include\"&$pragmaFile
         If Not FileExists($absolutePath) Then
            _FPUIError("include pointing to inexistent file at "&$absolutePath)
            ContinueLoop
         EndIf
         If _isInRecursionMemory($pragmaFile) Then ContinueLoop
         _addToRecursionMemory($pragmaFile)
         FileCopy($absolutePath, $folder&"\"&$pragmaFile, 1+8)
         _copyIncludesToFolder($absolutePath, $folder)
      ElseIf $prefix == '"' Then ; include from specified folder
         ; TODO (optional) implement
      EndIf

   WEnd

EndFunc

Func _isInRecursionMemory($fileName)
   For $i = 1 To UBound($includeRecursionMemory)-1
     If $includeRecursionMemory[$i] == $fileName Then Return True
   Next
   Return False
EndFunc

Func _addToRecursionMemory($fileName)
   ReDim $includeRecursionMemory[UBound($includeRecursionMemory)+1]
   $includeRecursionMemory[UBound($includeRecursionMemory)-1] = $fileName
EndFunc

Func zoomin()
   Send("^")
   MouseWheel("down",5)
EndFunc

Func zoomout()
   Send("^")
   MouseWheel("up",5)
EndFunc

Func OnAutoItExit()
EndFunc