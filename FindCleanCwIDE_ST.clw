!The functions to use StringTheory
!SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS Section Global SSSSSSSSSSSSSSSSSSSSSSSSSS
    SECTION('Global')   !INCLUDE('FindCleanCwIDE_ST.clw','GLOBAL')

    INCLUDE('StringTheory.inc'),ONCE
    INCLUDE('BigBangTheory.inc'),ONCE  !From https://github.com/CarlTBarnes/StringTheory-LoadFile-Split-Viewer
                                       !A way to view the ST Object to visually check what your ST code is doing
BangView    SHORT(0)                   !Set to (1) to show Bang windows to help debug
BangCls     BigBangTheory              !It add clutter to the code but allows visually checking
    MAP
ST_CleanClaPropXmlFile Procedure(STRING pClaPropXmlFN, BYTE pQuery, *ClnStatsType ClnStats, *STRING OutMsg ),BOOL
ST_CleanXmlFindPattern Procedure(StringTheory st, STRING ltPatternsElement, *IOStatsType IOStats, *STRING OutMsg ),BOOL
    END

!SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS Section Functions SSSSSSSSSSSSSSSSSSSSSSSSSS  
    SECTION('Functions')   !INCLUDE('FindCleanCwIDE_ST.clw','Functions')

ST_CleanClaPropXmlFile Procedure(STRING pClaPropXmlFN, BYTE pQuery, *ClnStatsType ClnStats, *STRING OutMsg )!,BOOL
DidSaveOk   BOOL
CleanCnt    LONG
Pos1        LONG
Pos2        LONG
B4CleanName STRING(260)
st          StringTheory
    CODE
    B4CleanName=CLIP(pClaPropXmlFN) & '.b4clean'
    CLEAR(ClnStats)
    OutMsg=''
    IF ~st.loadFile(pClaPropXmlFN) THEN 
         OutMsg='Error LoadFile: ' & st.LastError
         RETURN False
    END  
?     IF BangView THEN BangCls.ValueView(St,'LoadFile: ' & pClaPropXmlFN ).

    CleanCnt = ST_CleanXmlFindPattern(st, ltFindPatterns,    ClnStats.Find, OutMsg ) |
             + ST_CleanXmlFindPattern(st, ltReplacePatterns, ClnStats.Repl, OutMsg )
    IF CleanCnt=0 THEN 
       IF ~OutMsg THEN OutMsg = 'Below Max ' & Glo:MaxPatterns .
       RETURN False
    END     
?     IF BangView THEN BangCls.ValueView(St,'After Shrink Find ' & ClnStats.Find.CntIN &' to '& ClnStats.Find.CntOUT &' and Replace' ).

    IF pQuery THEN        !Query does not Save so we're done
       OutMsg=''
       RETURN True        !Clean had Count with no problems so return True       
      
    ELSIF Glo:TestShrink THEN     !Write TEST so write .TestShrink 
       DidSaveOk = St.SaveFile(CLIP(pClaPropXmlFN) & '.TestShrink')
       IF ~DidSaveOk THEN
          OutMsg='Error Save TestShrink: ' & st.LastError
       ELSE
          OutMsg='~{5} .TestShrink Saved OK ~{5}'
       END
       RETURN DidSaveOk                   
    END
    
    !--- This is NOT a Test...so WRITE to real ClaProps.XML --------
    COPY(B4CleanName,CLIP(B4CleanName) &'2')   !Save 2nd backup .b4clean2 
    COPY(pClaPropXmlFN,B4CleanName)            !Save .b4clean backup with Copy
    IF ERRORCODE() THEN                        !Cannot Backup file?
       OutMsg='Error Copy .b4clean: ' & ErrorCode() &' '& Error()
       Message(CLIP(OutMsg) & |
               '||From: ' & CLIP(pClaPropXmlFN) & '||To: ' & CLIP(B4CleanName), 'Copy Fail', ICON:Exclamation) 
       RETURN False  !Copy failed
    END
    DidSaveOk = st.SaveFile(pClaPropXmlFN)
    IF ~DidSaveOk THEN
       OutMsg='Error SaveFile: ' & st.LastError
    ELSE 
       OutMsg='*{9} Cleaned Ok *{5}'
    END
    RETURN DidSaveOk 

!====================================================================
! Xtra Functions called by above  Code from Geoff and tweaked by Carl
!====================================================================

ST_CleanXmlFindPattern Procedure(StringTheory st, STRING ltPatternsElement, *IOStatsType IOStats, *STRING OutMsg )!,BOOL
lDelim  String('<0C3h,0BFh>') 
lStart  Long         !Start of Patterns 1 byte after: Value="
lEnd    Long         !End of Patterns 1 byte before:         " />
lRemove Long         !Start of Removed Patterns > Min to Keep - to lEnd
lBytesRemoved Long
bangSt  StringTheory
  CODE
  CLEAR(IOStats) 
  st.findBetweenPosition(clip(ltPatternsElement) &'<32>','>', lStart, lEnd, ,false) !,,false=>CaseSens,Incluse <>
  IF lStart <= 0 OR lStart > lEnd
    OutMsg='Did not find "' & ltPatternsElement &'"  '&OutMsg
    RETURN false
  END
?    IF BangView THEN BangCls.StringView(St.Slice(lStart,lEnd),'['& lStart &' : '& lEnd &'] findBetweenPosition ' & ltPatternsElement ).

  st.FindMatchPosition(' value *= *".*"',lStart,lEnd)  !Find value="xxx" inside: <Element >
  IF lStart <= 0 OR lStart > lEnd
    OutMsg='No value= in "' & ltPatternsElement & '"  '&OutMsg
    RETURN false
  END
?    IF BangView THEN BangCls.StringView(St.Slice(lStart,lEnd),'['& lStart &' : '& lEnd &'] FindMatchPosition value=".*"' ).

  lStart = st.findchar('"',lStart) + 1  !Find first " in: value="xxx" >    then +1 so after it
  lEnd -= 1                             !lEnd was last " found by FindMatchPosition() then -1 so before it
  IF lStart > lEnd THEN                 !must have been value=""  so zero items
    RETURN false
  END
?    IF BangView THEN BangCls.StringView(St.Slice(lStart,lEnd),'['& lStart &' : '& lEnd &'] findChar "' ).
?    IF BangView THEN bangSt.SetValue(St.Slice(lStart,lEnd)) ; bangSt.Split(lDelim) ; BangCls.LinesViewInList(bangSt,'Split ['& lStart &' : '& lEnd &'] '& ltPatternsElement).

  IOStats.BytesIN = lEnd - lStart + 1                
  IOStats.CntIN = st.count(lDelim,1,lStart,lEnd) + 1 
  IF IOStats.CntIN <= Glo:MaxPatterns THEN
     RETURN False
  END
  lRemove=lStart
  IF Glo:MinPatterns > 0 THEN 
    lRemove -= size(lDelim)
    LOOP Glo:MinPatterns TIMES
      lRemove = st.findChars(lDelim,lRemove+size(lDelim),lEnd)
      IF ~lRemove THEN RETURN FALSE.
    END 
    IOStats.CntOUT = Glo:MinPatterns 
  END
?   IF BangView THEN BangCls.StringView(St.Slice(lRemove,lEnd - lRemove + 1),'['& lRemove &' : '& lEnd &'] removeFromPosition for ' & ltPatternsElement ).
?   IF BangView THEN BangCls.StringView(St.Slice(lStart,lRemove-1),'['& lStart &' : '& lRemove-1 &'] Keep Min '& Glo:MinPatterns &' ' & ltPatternsElement ).
?   IF BangView THEN bangSt.SetValue(St.Slice(lStart,lRemove-1)) ; bangSt.Split(lDelim) ; BangCls.LinesViewInList(bangSt,'Split ['& lStart &' : '& lRemove-1 &'] '& ltPatternsElement).
  
  lBytesRemoved = lEnd - lRemove + 1 
  st.removeFromPosition(lRemove,lBytesRemoved)  ! remove after MinPatterns, keep before
  IOStats.BytesOUT = IOStats.BytesIN - lBytesRemoved
  Return TRUE   !True if removed stuff   

    