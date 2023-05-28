; XML Auto-Doc
; =================================
; Builds generic documentation for a set of XML files
; Gathers element properties: Name, Children, Attribute(s), Text
; Uses some basic XML validation & error checking

#include <Array.au3>
#include <StringConstants.au3>

Global Const $RimWorldPath = GetRimWorldPath()
Global Const $VERSION = GetRimWorldVer()
Global Const $SpecialTags = ['li', 'defName'] ; It also looks for Attributes containing 'Properties_'
Global Const $OutPutPath = @ScriptDir & '\XML.html'
Global Enum $_NAME, $_PARENT, $_CHILD, $_ATTRIB, $_TEXT, $_EXAMPLES, $__MAX

Main()

Func Main()

	#Region Gather XML data

	; Initialize & List XML files
	Local Const $XML_Root = '_root_'
	Local $file, $i, $ID, $path, $parent, $XML_Table[1][$__MAX], $XML_Chain, $ElementName, $attribs, $TableSize = 0
	Local $XML_List = StringTrimRight(FileList($RimWorldPath), 1)
	$XML_List = StringSplit($XML_List, @LF, $STR_NOCOUNT)
	$XML_Table[0][$_NAME] = $XML_Root
	For $XML_File In $XML_List

		; Read XML file
		$file = FileRead($XML_File)
		If @error Then
			ConsoleWrite("ERROR reading file: " & $XML_File & @LF & @LF)
			ContinueLoop
		EndIf
		$path = '..' & StringMid($XML_File, StringInStr($XML_File, '\Mods\') + 5)

		; Remove visual formatting
		$file = StringStripCR($file)												; Remove carriage returns
		$file = StringRegExpReplace($file, "(?U)(?s)(<\?.*\?>)*(<!--.*-->)*", "")	; Remove comments & XML directives
		$file = StringReplace($file, "<", @LF & "<", 0, $STR_CASESENSE)				; Linefeed break before XML tag
		$file = StringReplace($file, ">", ">" & @LF, 0, $STR_CASESENSE)				; Linefeed break after XML tag
		$file = StringReplace($file, @LF & @LF, @LF, 0, $STR_CASESENSE)				; Replace double linefeeds with a single

		; Parse elements & text
		$XML_Chain = $XML_Root
		For $FullElement In StringSplit($file, @LF, $STR_NOCOUNT)
			If StringStripWS($FullElement, $STR_STRIPALL) = '' Then ContinueLoop
			If StringInStr($FullElement, '<', $STR_CASESENSE) Then $ElementName = StringRegExp($FullElement, '</*([\S]+)[ />]', 3)[0]
			$parent = StringMid($XML_Chain, StringInStr($XML_Chain, '|', $STR_CASESENSE, -1) + 1)

			; Special Cases
			For $SpecialCase In $SpecialTags
				If $ElementName = $SpecialCase Then
					If StringLeft($FullElement, 2) = '</' Then
						$ElementName = $parent
					ElseIf StringInStr($FullElement, 'Class="') And StringInStr($FullElement, 'Properties_') Then
						$ElementName = HTML_Encode($parent & ' <' & StringRegExp($FullElement, '(?U)<(.*)/?>', $STR_REGEXPARRAYGLOBALMATCH)[0] & '>')
					Else
						$ElementName = HTML_Encode($parent & '  <' & $SpecialCase & '>')
					EndIf
					ExitLoop
				EndIf
			Next

			; Close element tag
			If StringLeft($FullElement, 2) = '</' Then
				If $ElementName = StringMid($XML_Chain, StringInStr($XML_Chain, '|', $STR_CASESENSE, -1) + 1) Then
					$XML_Chain = StringLeft($XML_Chain, StringInStr($XML_Chain, '|', $STR_CASESENSE, -1) - 1)
				Else
					ConsoleWrite("ERROR -- Incorrect element closed -- file: " & $path & @LF & _
								"Current XML Chain: " & $XML_Chain & @LF & _
								"Full element received: " & $FullElement & @LF & _
								"Attempted to close: " & $ElementName & @LF & _
								"Expected: " & StringMid($XML_Chain, StringInStr($XML_Chain, '|', $STR_CASESENSE, -1) + 1) & @LF & _
								"Aborting this file." & @LF & @LF)
					ContinueLoop 2
				EndIf

			; Open element tag
			ElseIf StringLeft($FullElement, 1) = '<' Then

				; Parse Attributes
				$attribs = ""
				If StringInStr($FullElement, '=', $STR_CASESENSE) > 0 Then $attribs = StringRegExp($FullElement, '(?U)([\S]+=".+")', 3)

				; New or Known Element?
				$ID = -1
				For $i = 0 To $TableSize
					If $XML_Table[$i][$_NAME] = $ElementName Then
						$ID = $i
						ExitLoop
					EndIf
				Next
				If $ID = -1 Then
					$TableSize += 1
					$ID = $TableSize
					ReDim $XML_Table[$ID + 1][$__MAX]
					$XML_Table[$ID][$_NAME] = $ElementName
				EndIf

				; Update XML table: Parents, Attributes, Examples
				If Not StringInStr($XML_Table[$ID][$_PARENT], '>' & $parent & '<') Then $XML_Table[$ID][$_PARENT] &= '<a href="#' & $parent & '">' & $parent & '</a>' & @LF
				If IsArray($attribs) Then
					For $attrib In $attribs
						If Not StringInStr($XML_Table[$ID][$_ATTRIB], '>' & $attrib & '<', $STR_CASESENSE) Then $XML_Table[$ID][$_ATTRIB] &= '<li>' & $attrib & '</li>' & @LF
					Next
				EndIf
				If Not StringInStr($XML_Table[$ID][$_EXAMPLES], '>' & $path & '<') Then $XML_Table[$ID][$_EXAMPLES] &= '<li>' & $path & '</li>' & @LF

				; Update XML "chain" of elements (ignore self-closing elements)
				If StringRight($FullElement, 2) <> '/>' Then $XML_Chain &= '|' & $ElementName

			; Parse Text block
			Else
				For $i = 0 To $TableSize
					If $XML_Table[$i][$_NAME] = StringMid($XML_Chain, StringInStr($XML_Chain, '|', $STR_CASESENSE, -1) + 1) Then
						If Not StringInStr($XML_Table[$i][$_TEXT], '>' & $FullElement & '<') Then
							$XML_Table[$i][$_TEXT] &= '<li>' & $FullElement & '</li>' & @LF
							If Not StringInStr($XML_Table[$ID][$_EXAMPLES], '>' & $path & '<') Then $XML_Table[$ID][$_EXAMPLES] &= '<li>' & $path & '</li>' & @LF
						EndIf
						ExitLoop
					EndIf
				Next
			EndIf
		Next
		If $XML_Chain <> $XML_Root Then ConsoleWrite("ERROR in file: .." & $path & @LF & "End of file reached but not all elements were closed." & @LF & "Current XML Chain: " & $XML_Chain & @LF & @LF)
	Next
	#EndRegion

	#Region XML Processing

	; Infer Child elements from Parents
	For $i = 0 To $TableSize
		For $j = 0 To $TableSize
			If StringInStr($XML_Table[$i][$_PARENT], '>' & $XML_Table[$j][$_NAME] & '</', $STR_CASESENSE) > 0 Then
				$XML_Table[$j][$_CHILD] &= '<a href="#' & $XML_Table[$i][$_NAME] & '">' & $XML_Table[$i][$_NAME] & '</a>' & @LF
			EndIf
		Next
	Next

	; Sort the results & output stats
	_ArraySort($XML_Table)
	$hFile = FileOpen(@ScriptDir & '\XML Stats.txt', 2)
	FileWriteLine($hFile, "Element" & @TAB & "Parents" & @TAB & "Children" & @TAB & "Attribs" & @TAB & "Text" & @TAB & "Examples")
	For $i = 0 to $TableSize
		FileWriteLine($hFile, $XML_Table[$i][$_NAME] & @TAB & StringCount($XML_Table[$i][$_PARENT]) & @TAB & StringCount($XML_Table[$i][$_CHILD]) & @TAB & StringCount($XML_Table[$i][$_ATTRIB]) & @TAB & StringCount($XML_Table[$i][$_TEXT]) & @TAB & StringCount($XML_Table[$i][$_EXAMPLES]))
		If $XML_Table[$i][$_PARENT] <> "" Then $XML_Table[$i][$_PARENT] = SortRow($XML_Table[$i][$_PARENT], ', ')
		If $XML_Table[$i][$_CHILD] <> "" Then $XML_Table[$i][$_CHILD] = SortRow($XML_Table[$i][$_CHILD], ', ')
		If $XML_Table[$i][$_ATTRIB] <> "" Then $XML_Table[$i][$_ATTRIB] = SortRow($XML_Table[$i][$_ATTRIB], @LF)
		If $XML_Table[$i][$_TEXT] <> "" Then $XML_Table[$i][$_TEXT] = SortRow($XML_Table[$i][$_TEXT], @LF)
		If $XML_Table[$i][$_EXAMPLES] <> "" Then $XML_Table[$i][$_EXAMPLES] = SortRow($XML_Table[$i][$_EXAMPLES], @LF)
	Next
	FileClose($hFile)
	#EndRegion

	#Region HTML Output

	; Access Output File
	$hFile = FileOpen($OutPutPath, 2)
	If $hFile = -1 Then
		ConsoleWrite("ERROR - cannot access output file: " & $OutPutPath & @LF & "Aborted." & @LF & @LF)

	; Output Documentation
	Else

		; Header
		FileWriteLine($hFile, '<html><head><style>')
		FileWriteLine($hFile, 'body {font-family: sans-serif;}')
		FileWriteLine($hFile, '#HTML_Side {background-color: #ddd; height: 95%; width: 28%; margin-right: 10px; padding: 0 20px 0 0; overflow: auto; float: left;}')
		FileWriteLine($hFile, '#HTML_Info {background-color: #ddd; height: 95%; margin-right: 5px; padding: 0 10px; overflow: auto; display: block;}')
		FileWriteLine($hFile, 'hr {background-color: #fff; height: 10px; width: 100%; margin-left: -10px; padding-right: 20px; border: 0;}')
		FileWriteLine($hFile, 'h1, h2 {margin: 3px; text-align: center;}')
		FileWriteLine($hFile, 'h3 {margin: 10px 0 15px;}')
		FileWriteLine($hFile, '#HTML_Side a {display: block; padding: 5px;}')
		FileWriteLine($hFile, '#HTML_Side a:hover {background-color: #eee;}')
		FileWriteLine($hFile, '</style></head>')
		FileWriteLine($hFile, '<body>')
		FileWriteLine($hFile, '<h1>XML Auto-Documentation for ' & $VERSION & '</h1>')
		FileWriteLine($hFile, '<div id="HTML_Side">')

		; Nav bar
		For $i = 0 To $TableSize
			FileWriteLine($hFile, '<a href="#' & $XML_Table[$i][$_NAME] & '">' & $XML_Table[$i][$_NAME] & '</a>')
		Next

		; Body
		FileWriteLine($hFile, '</div><div id="HTML_Info">')
		For $i = 0 To $TableSize

			; Name
			$ElementName = $XML_Table[$i][$_NAME]
			FileWriteLine($hFile, '<h2 id="' & $XML_Table[$i][$_NAME] & '">' & $XML_Table[$i][$_NAME] & '</h2>')

			; Parent
			If $XML_Table[$i][$_PARENT] <> "" Then
				FileWriteLine($hFile, "<h3>Parents:</h3>")
				FileWriteLine($hFile, $XML_Table[$i][$_PARENT])
			EndIf

			; Child
			If $XML_Table[$i][$_CHILD] <> "" Then
				FileWriteLine($hFile, "<h3>Children:</h3>")
				FileWriteLine($hFile, $XML_Table[$i][$_CHILD])
			EndIf

			; Attributes
			If $XML_Table[$i][$_ATTRIB] <> "" Then
				FileWriteLine($hFile, "<h3>Attributes:</h3>")
				FileWriteLine($hFile, $XML_Table[$i][$_ATTRIB])
			EndIf

			; Text
			If $XML_Table[$i][$_TEXT] <> "" Then
				FileWriteLine($hFile, "<h3>Text:</h3>")
				FileWriteLine($hFile, $XML_Table[$i][$_TEXT])
			EndIf

			; Examples
			If $XML_Table[$i][$_EXAMPLES] <> "" Then
				FileWriteLine($hFile, "<h3>Examples:</h3>")
				FileWriteLine($hFile, $XML_Table[$i][$_EXAMPLES])
			EndIf
			If $i <> $TableSize Then FileWriteLine($hFile, "<hr>" & @CRLF)
		Next
	EndIf

	; Close HTML & output file
	FileWriteLine($hFile, '</div></body></html>')
	FileClose($hFile)
	ConsoleWrite("Finished:" & @TAB & $VERSION & @LF & $OutPutPath & @LF)
	#EndRegion

	; Alert user when done
	SoundPlay(@WindowsDir & "\media\chimes.wav", 1)
EndFunc

Func GetRimWorldPath()
	MsgBox(0, "XML Auto-Doc", "Choose the RimWorld mod folder you want to document" & @CRLF & @CRLF & "RimWorld\Mods\Core\Defs is recommended" & @CRLF & @CRLF & "XML Auto-Doc works recursively, so just choosing the Mods folder is NOT recommended!")
	Local $path = FileSelectFolder("Choose mod folder (Mods\Core\Defs recommended)", @ScriptDir)
	If $path = "" Then Exit
	Return $path
EndFunc

Func GetRimWorldVer()
	Local $path = $RimWorldPath
	While Not FileExists($path & '\Version.txt') And StringInStr($path, '\')
		$path = StringLeft($path, StringInStr($path, '\', $STR_CASESENSE, -1) - 1)
	WEnd
	If FileExists($path & '\Version.txt') Then
		Return FileReadLine($path & '\Version.txt')
	EndIf
	Return $RimWorldPath
EndFunc

Func FileList($path)
	Local $file, $hFile, $List = ""
	$hFile = FileFindFirstFile($path & '\*.*')
	If $hFile = -1 Then Return $List
	While 1
		$file = $path & '\' & FileFindNextFile($hFile)
		If @error Then ExitLoop
		If StringInStr(FileGetAttrib($file), 'D') > 0 Then
			$List &= FileList($file)
		Else
			If StringLower(StringRight($file, 4)) = '.xml' Then $List &= $file & @LF
		EndIf
	WEnd
	FileClose($hFile)
	Return $List
EndFunc

Func StringCount($string)
	If $string = "" Then Return 0
	Local $i = 1
	For $j = 1 To StringLen($string)
		If StringMid($string, $j, 1) = @LF Then $i += 1
	Next
	Return $i
EndFunc

Func HTML_Encode($string)
	Local $output = ""
	$string = StringToASCIIArray($string, 0, StringLen($string), $SE_UTF8)
	For $chr In $string
		Switch $chr
			Case 40 To 57, 64 To 123
				$output &= ChrW($chr)
			Case Else
				$output &= '&#' & $chr & ';'
		EndSwitch
	Next
	Return $output
EndFunc

Func SortRow($Sort, $Delimiter)
	$Sort = StringTrimRight($Sort, 1)
	$Sort = StringSplit($Sort, @LF, $STR_NOCOUNT)
	_ArraySort($Sort)
	Return _ArrayToString($Sort, $Delimiter)
EndFunc
