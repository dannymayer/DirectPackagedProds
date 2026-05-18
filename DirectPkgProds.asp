<%@ Language=VBScript %>
<%Option Explicit%>
<%
	Response.Buffer = True
	Server.ScriptTimeout = 7200
	
	'Standard variables
	Dim strUID				'Logged in user ID
	Dim intMenuLite			'Which menu light should be lit
	Dim intDept				'Department identifier
	Dim strStaffTitle		'Department title

	'Set variable defaults
	intDept = 1				'Department for news
	strStaffTitle = "Accounting"
	intMenuLite = 6
	strPgTitle = "Direct Packaged Products"		'Page title for header and breadcrumbs
	
	'Page specific variables
	Dim c, i, ii, count, strMyID, strLastName, strWhereEtc, strWhereAcct, strWhereRep, strWhereClosed, strOrderBy, strBGColor, intRecords
	Dim strSortType, strSearchType, strDirection, strSelect, strRepnum, strPrevPage, strSelectList, intRepCount, strSQLr
	Dim conn, strMonth, strYear, strSQLmy, rsmy, strWhereMonth, strSearchVal, strSQLms, rst, rsms, rsr, strTEMP, ce, strStep, intTotal
	Dim strREP_UID			'
	Dim arrWho, arrSort, strCurRep, arrRepList', strHref				'
	Dim	strSelRep			'
	Dim arrDPP				'
	Dim blDPP_Admin			'
	Dim blDPP_Admin_View	'
	Dim strDPP_Admin		'DPP Admin Name
	Dim strSQL_DPP			'
	'Dim blExcel			'Excel Switch
	
	c = 0
	i = 0
	ii = 0
	count = 0
	'strMyID = 0
	strLastName = ""
	strWhereEtc = ""
	strWhereAcct = ""
	strWhereRep = ""
	strWhereClosed = ""
	strOrderBy = ""
	strBGColor = "#ffffff"
	intRecords = 0
	intTotal = 0
	strSearchVal = Request.Form("searchval")
	'strDirection = Request.Form("direction")
	'strSelect = Request.Form("select")
	strMyID = Request.Form("myID")
	'strPrevPage = Request.ServerVariables("HTTP_REFERER")
	strUID = Request.ServerVariables("AUTH_USER")
	
	'Grab UserID
	If Len(strUID) > 9 And LCase(Left(strUID,9)) = "r2wserv2\" Then
		strUID = Right(strUID,(Len(strUID)-9))
	End If
	

	If LCase(strUID) = "mcampbell" OR LCase(strUID) = "jbulava" Then
		strUID = "0KAC23"
	End If

	If LCase(strUID) = "n.kholdebarin" Then
		strUID = "0KAC88"
	End If

	If LCase(strUID) = "dmayer" Then
		strUID = "0KAC88"
	End If

	If LCase(strUID) = "fmonte" Then
		strUID = "0KA056"
	End If

	'Set the 'Rep' UID
	If Len(Request.Form("rep")) > 0 AND LCase(Request.Form("rep")) <> "admin" Then
		Select Case LCase(Request.ServerVariables("AUTH_USER"))
			Case "bkn002","bkn001","0ka411","0ka755","0ka111"
				strREP_UID = strUID
			Case Else
				If Left(LCase(Request.Form("rep")),5) = "admin" Then
					strREP_UID = Right(Request.Form("rep"),Len(Request.Form("rep"))-5)
				Else
					strREP_UID = Request.Form("rep")
				End If
		End Select
	Else
		strREP_UID = strUID
	End If
	'response.write strREP_UID & " - " & strUID
	Dim bc, strRefURL
	Set bc = Server.CreateObject("MSWC.BrowserType")
	
	'Connect to DB
	If IsObject(Session("Reps_conn")) Then
	    Set conn = Session("Reps_conn")
	Else
	    Set conn = Server.CreateObject("ADODB.Connection")
	    conn.open "WebReps","web","#5aUS4g3"
	    conn.CommandTimeout=0
	    Set Session("Reps_conn") = conn
	End If
	
	'Detect DPP Admins
	strSQL_DPP = "SELECT T_E_Services.lasalle_st_ID, vwREPALL.DPP_ADMIN " &_
				 "FROM vwREPALL INNER JOIN " &_
                 "T_E_Services ON vwREPALL.ID = T_E_Services.ID " &_
				 "WHERE vwREPALL.DPP_ADMIN = 1 AND vwREPALL.LASL_ACTIVCODE = N'Active' AND T_E_Services.lasalle_st_ID = '" & strUID & "'"
	'response.write strSQL_DPP
	Set rst = conn.Execute(strSQL_DPP)

	If Not rst.EOF Then
		arrDPP = rst.GetRows
		blDPP_Admin = arrDPP(1,0)
		blDPP_Admin_View = blDPP_Admin
		'Admin view
		If Len(Request.Form("rep")) > 0 AND Left(LCase(Request.Form("rep")),5) <> "admin" Then
			blDPP_Admin_View = False
		End If
	End If

	rst.Close
	Set rst = Nothing
'response.write blDPP_Admin & "<br>"
'Filters
'	Month
'Excel
'Print
'Admin
'	Rep
'	Sub rrs
'	type
'	search
'	sort rep
'	sort fund
'	sort type
'	sort cust
'	sort invest
'	sort total
'sort t-date
'	sort spon acct
	
'response.write (StrComp(strREP_UID,Request.Form("curRep"),1) <> 0) & "<br>"

	'Check for new rep
	If (StrComp(strREP_UID,Request.Form("curRep"),1) <> 0) = True Then
		'response.write "new?<br>"
		'New Rep
		strCurRep = strREP_UID
		strSortType = "cust"
		strDirection = "ASC"
		strRepnum = "all"
		strMyID = ""
		strSearchVal = "ALL"
		strSearchType = ""
	Else
		'Same Rep
		strCurRep = Request.Form("curRep")
		strRepnum = Request.Form("repnum")
		strMyID = Request.Form("myID")
		
		'Sort
		If Len(Request.Form("sort")) > 0 Then
			arrSort = Split(Request.Form("sort"),",")
			strSortType = arrSort(0)
			
			If arrSort(1) = "az" Then
				strDirection = "ASC"
			Else
				strDirection = "DESC"
			End If
		Else
			strSortType = "cust"
			strDirection = "ASC"
		End If
		
		'Set search parameters
		strSearchType = Request.Form("searchtype")
		
		If LCase(strSearchVal) <> "all" Then
			strSearchVal = UCase(Trim(strSearchVal))
		Else
			strSearchVal = "ALL"
		End If
	End If

	'Set SQL to retrieve selected month or set default
	If Len(strMyID) > 0 Then
		strSQLmy = "SELECT * FROM vwDIRECT_PKG_PRODS_MONTHS WHERE myID = " & strMyID
	Else
		strSQLmy = "SELECT * FROM vwDIRECT_PKG_PRODS_MONTHS " &_ 
		"WHERE myID = (SELECT MAX(myID) FROM vwDIRECT_PKG_PRODS_MONTHS)"
	End If
	
	Set rsmy = Server.CreateObject("ADODB.Recordset")
	rsmy.Open strSQLmy, conn
	
	'Get selected month/year or set to default
	If Len(strMyID) = 0 Then
		strMonth = rsmy("MONTH")
		strYear = rsmy("YEAR")
	Else
		'strMonth = Replace(Right(Request.Form("myID"),2),"0","")
		strMonth = Right(Request.Form("myID"),2)
		strYear = Left(Request.Form("myID"),4)
	End If
	
	If IsObject(rsmy) Then
		If Len(strMyID) > 0 Then
			strWhereMonth = " AND (vwDIRECT_PKG_PRODS.MONTH='" & rsmy("MONTH") & "') AND (vwDIRECT_PKG_PRODS.YEAR='" & rsmy("YEAR") & "')"
		Else
			strWhereMonth = " AND (vwDIRECT_PKG_PRODS.MONTH='" & strMonth & "') AND (vwDIRECT_PKG_PRODS.YEAR='" & strYear & "')"
		End If
	End If
	
	If IsObject(rsmy) Then
	 	rsmy.Close
		Set rsmy = Nothing
	End If

  'Set Repnum view
  If Len(strRepnum) = 0 Then
  	strRepnum = "all"
  End If

  If LCase(strRepnum) = "all" Then
	'Nothing
  ElseIf Len(strRepnum) > 0 Then
	strWhereRep = " AND vwDIRECT_PKG_PRODS.REPNUM = '" & strRepnum & "' "
  End If

  If Len(strSearchType) > 0 Then
    Select Case strSearchType
	  Case "trl"
  		strWhereAcct = " AND vwDIRECT_PKG_PRODS.BATCH Like 'TRAILS' "
		strSearchVal = "ALL"
	  Case "mut"
  		strWhereAcct = " AND vwDIRECT_PKG_PRODS.BATCH Like 'MUTUALS' "
		strSearchVal = "ALL"
	  Case "ins"
  		strWhereAcct = " AND vwDIRECT_PKG_PRODS.BATCH Like 'INSURANCE' "
		strSearchVal = "ALL"
	  Case "fnd"
  		strWhereAcct = " AND vwDIRECT_PKG_PRODS.FUND_NAME LIKE '%" & strSearchVal & "%' "
	  Case "cus"
  		strWhereAcct = " AND vwDIRECT_PKG_PRODS.CUSTOMER Like '%" & strSearchVal & "%' "
	  Case "tdt"
	  	If IsDate(strSearchVal) = True Then
  			strWhereAcct = " AND vwDIRECT_PKG_PRODS.TRADE_DATE = '" & strSearchVal & "' "
		Else
			strWhereAcct = " AND vwDIRECT_PKG_PRODS.TRADE_DATE = '" & Date & "' "
		End If
	  Case "spn"
  		strWhereAcct = " AND vwDIRECT_PKG_PRODS.SPON_ACCT Like '%" & strSearchVal & "%' "
	  Case "all"
	    strSearchVal = "ALL"
	End Select
  End If

  'Reset sort on new rep
  'Select Case strCurRep
  '	Case ""
'		strCurRep = strRep_UID
'	Case Request.Form("curRep")
'		strCurRep = Request.Form("curRep")
'	Case Else
'  		strCurRep = strRep_UID
'  End Select
  	
  Select Case strSortType
  	Case "rep"
		strOrderBy = " ORDER BY vwDIRECT_PKG_PRODS.REPNUM " & strDirection & ", vwDIRECT_PKG_PRODS.CUSTOMER " & strDirection
  	Case "fund"
		strOrderBy = " ORDER BY vwDIRECT_PKG_PRODS.FUND_NAME " & strDirection & ", vwDIRECT_PKG_PRODS.CUSTOMER " & strDirection
  	Case "type"
		strOrderBy = " ORDER BY vwDIRECT_PKG_PRODS.BATCH " & strDirection
  	Case "cust"
		strOrderBy = " ORDER BY vwDIRECT_PKG_PRODS.CUSTOMER " & strDirection
  	Case "inv"
		strOrderBy = " ORDER BY vwDIRECT_PKG_PRODS.INVEST " & strDirection & ", vwDIRECT_PKG_PRODS.CUSTOMER " & strDirection
	Case "comm"
		strOrderBy = " ORDER BY vwDIRECT_PKG_PRODS.COMM " & strDirection & ", vwDIRECT_PKG_PRODS.CUSTOMER " & strDirection
  	Case "spon"
		strOrderBy = " ORDER BY vwDIRECT_PKG_PRODS.SPON_ACCT " & strDirection & ", vwDIRECT_PKG_PRODS.CUSTOMER " & strDirection
  	Case "iort"
		strOrderBy = " ORDER BY vwDIRECT_PKG_PRODS.TYPE " & strDirection & ", vwDIRECT_PKG_PRODS.CUSTOMER " & strDirection
  	Case Else
		strOrderBy = " ORDER BY vwDIRECT_PKG_PRODS.CUSTOMER ASC"
  End Select

  strWhereEtc = strWhereRep & strWhereAcct & strWhereMonth

  'if len(strSortType) = 0 then
  'end if
%>
<html>
<head>
	<title>LaSalle St. Securities, LLC - <%=strStaffTitle%>&nbsp;<%=strPgTitle%></title>
	<META content="MSHTML 6.00.2800.1400" name=GENERATOR>
	<meta http-equiv="pragma" content="no-cache">
	<link rel="shortcut icon" href="/images/LaSalleSt.ico">
	<link rel=stylesheet type="TEXT/CSS" href="/css/MainStyle.css">
	<SCRIPT language="JavaScript" SRC="/js/root.js"></SCRIPT>
	<script type="text/javascript">
		function OnSubmitForm()
		{
		  var page = "DirectPkgProds.asp";
		  
		  //alert(document.reps.srtRep.value);
		  //if(document.pressed == 'Export to Excel')
		  //{
		  // document.reps.action = page + "?fn=excel";
		  //}
		  //else
		  //if(document.pressed == 'Print')
		  //{
		  //  document.reps.action = page + "?fn=print";
		  //}
		  //else
		  if(document.reps.searchtype.value == 'cus' || document.reps.searchtype.value == 'tdt'
		  	|| document.reps.searchtype.value == 'fnd' || document.reps.searchtype.value == 'spn'){
		  	document.reps.searchval.select();
			document.reps.searchval.focus();
		  }
		  else
		  {
		  	document.reps.action = page;
			document.reps.submit();
		  }
		  return true;
		}
	</script>
</HEAD>
<%If Request.Form("print") = "Print" Then %><body bgcolor="#FFFFFF" background="/images/FFFFFF.jpg" leftmargin="0" topmargin="0" marginwidth="0" marginheight="0" onLoad="window.print();">
<table border="0" cellspacing="0" cellpadding="0" align="left" valign="top">
	<tr>
		<td align="center" valign="top" width="646"><!-- Begin Body Content -->
		  <table border="0" cellspacing="0" cellpadding="2" align="center" valign="top">
			<tr>
				<td valign="bottom" align="center">
					<table border="0" cellspacing="0" cellpadding="1" align="center" valign="top">
		  				<tr>
							<td valign="bottom" align="center">
								<table border="0" cellspacing="0" cellpadding="0" valign="top" align="center" WIDTH="640">
									<tr height="24">
			        					<td height="24" align="left" width="318" valign="middle" class="NavyTitle">
										<u>Direct Packaged Products for&nbsp;<%Response.Write strMonth & "/" & strYear%></u></td>
										<td height="24" align="left" width="100" valign="middle" class="NavyTitle">&nbsp;</td>
			        					<td align="right" width="222" height="24" valign="middle" class="WhiteTxt">
										<a href="javascript:history.back();" class="NavyTitle"><< Back</a><span class="NavyTitle">&nbsp;<strong>&#183;</strong>&nbsp;</span><a href="javascript:void(0);" onClick="window.print();" class="NavyTitle">Print</a></td>
									</tr>
								</table>
							</td>
						</tr>
					</table>
					<table BORDER="0" CELLSPACING="1" BORDERCOLOR="#000055" CELLPADDING="0" WIDTH="640">
						  <tr>
							<td nowrap bgcolor="#FFFFFF" align="left" class="NavyTxt"><strong><u>Rep#:</u></strong></td>
							<td nowrap bgcolor="#FFFFFF" align="center" class="NavyTxt"><strong><u>Fund:</u></strong></td>
							<td nowrap bgcolor="#FFFFFF" align="center" class="NavyTxt"><strong><u>Type:</u></strong></td>
							<td nowrap bgcolor="#FFFFFF" align="center" class="NavyTxt"><strong><u>Customer:</u></strong></td>
							<td nowrap bgcolor="#FFFFFF" align="right" class="NavyTxt"><strong><u>Invest:</u></strong></td>
							<td nowrap bgcolor="#FFFFFF" align="right" class="NavyTxt"><strong><u>Total:</u></strong></td>
							<td nowrap bgcolor="#FFFFFF" align="center" class="NavyTxt"><strong><u>Trade Date:</u></strong></td>
							<td nowrap bgcolor="#FFFFFF" align="center" class="NavyTxt"><strong><u>Spon Acct:</u></strong></td>
							<td nowrap bgcolor="#FFFFFF" align="center" class="NavyTxt"><strong><u>I/T:</u></strong></td>
						  </tr>
<%Else%>
<body bgcolor="#ffffff" leftmargin="0" topmargin="0" marginwidth="0" marginheight="0">
	<!-- Side menu parts -->
	<SCRIPT language=javascript src="/js/ypSlideOutMenus.js"></SCRIPT>
	<SCRIPT language=javascript src="/js/ypSlideOutMenuCoords.js"></SCRIPT>
	<SCRIPT language=javascript>
		// Courtesy of SimplytheBest.net (http://simplythebest.net/info/dhtml_scripts.html)
		var _version = 'Pre 1.2'; 
	</SCRIPT>
	<!--// Side menu parts -->
<DIV align=left>

<table border="0" cellspacing="0" cellpadding="0" align="left" valign="top" width="100%">
	<tr>		
		<td>
			<!-- #include virtual="inc/Header.asp" -->
			<TABLE width="100%" cellspacing="0" cellpadding="0" border="0">
			  	<tr>
				    <td colspan="4"><IMG SRC="/images/transparent.gif" WIDTH="5" HEIGHT="7" BORDER="0" ALT=""></td>
			  	</tr>
				<tr>
					<td valign="top" width="143"><!-- #include virtual="inc/MainMenu.asp" --></td>
				    <td width="5"><IMG SRC="/images/transparent.gif" WIDTH="8" HEIGHT="7" BORDER="0" ALT=""></td>
					<td align="center" valign="top">
					<!-- Begin Body Content -->
		  <table border="0" width="100%" cellspacing="0" cellpadding="2" align="left" valign="top">
			<tr>
				<td valign="bottom" align="center">
					<table border="0" cellspacing="0" cellpadding="1" align="center" valign="top" width="100%">
		  				<tr>
							<td valign="bottom" align="center">
								<table border="0" cellspacing="0" cellpadding="0" valign="top" align="center" WIDTH="100%">
									<tr><form name="reps" onSubmit="return OnSubmitForm();" method="post">
										<td width="75%" nowrap align="left" height="24" background="/images/tabs/NavyTab24Ht-1px-Line.gif" valign="middle" class="NavyTitle">Direct Packaged Products for&nbsp;<select name="myID" class="navtxt" onChange="form.submit();">
<%
  'Build month select list
  strSQLms = "SELECT TOP(13) * FROM vwDIRECT_PKG_PRODS_MONTHS WHERE MONTH > 0 ORDER BY YEAR DESC, MONTH DESC"

  	  Set rsms = Server.CreateObject("ADODB.Recordset")
	  rsms.Open strSQLms, conn

	    If IsObject(rsms) Then
	     While Not rsms.EOF

		If LCase(rsms("myID")) = strMyID Then
			strSelectList = "<option value='" & rsms("myID") & "' SELECTED>" & rsms("MONTH") & "/" & rsms("YEAR") & "</option>"
		Else
			strSelectList = "<option value='" & rsms("myID") & "'>" & rsms("MONTH") & "/" & rsms("YEAR") & "</option>"
		End If

		Response.Write strSelectList & vbcrlf & _
		 rsms.MoveNext
	     Wend
	    End If

	  If IsObject(rsms) Then
      	rsms.Close
    	Set rsms = Nothing
  	  End If
%>
																	  	
																	  </select></td>
										<td width="24" height="24" align="left" valign="middle" bgcolor="#000055"><img src="/images/tabs/NavyTab24Ht-24px-Angle.gif" width="24" height="24"></td>
						        		<td width="25%" nowrap align="center" bgcolor="#000055" height="24" background="/images/tabs/NavyTab24Ht-1px-Body.gif" valign="middle" class="WhiteTxtTitle">
										<INPUT TYPE="SUBMIT" onClick="document.pressed=this.value" VALUE="Export to Excel" name="excel" class="Button2">
										<INPUT TYPE="SUBMIT" onClick="document.pressed=this.value" VALUE="Print" name="print" class="Button2"></td>
										<td width="5" height="24" align="left" valign="middle"><img src="/images/tabs/NavyTab24Ht-5px-End.gif" width="5" height="24"></td> -->
									</tr>							
									<tr>
								      <td align="center" colspan="4"><img src="/images/whitedot.gif" width="600" height="3" border="0"></td>
								  	</tr>
								</table>
								<table border="0" cellspacing="0" cellpadding="0" valign="top" align="center" WIDTH="100%">
								  <tr>
									  <td nowrap align="left" class="NavyTitle"><%
									  		'Display underlings, if any
											Call whoRU(strUID,strREP_UID)%></td>
								      <td nowrap align="left" class="NavyTitle">&nbsp;Filter RR#s&nbsp;<%Call SelectRep()%>&nbsp;</td>
									  <td nowrap align="right" class="NavyTitle" colspan="3">
									  	  Filter by&nbsp;<select name="searchtype" class="navtxt" onchange="document.pressed=this.value;return OnSubmitForm();">
		 													<option value="all">Show All
															<option value="trl"<%If strSearchType = "trl" Then Response.Write " SELECTED" End If%>>Trails
															<option value="mut"<%If strSearchType = "mut" Then Response.Write " SELECTED" End If%>>Mutuals
															<option value="ins"<%If strSearchType = "ins" Then Response.Write " SELECTED" End If%>>Insurance
															<option value="fnd"<%If strSearchType = "fnd" Then Response.Write " SELECTED" End If%>>Fund
															<option value="cus"<%If strSearchType = "cus" Then Response.Write " SELECTED" End If%>>Customer
															<option value="tdt"<%If strSearchType = "tdt" Then Response.Write " SELECTED" End If%>>Trade Date
															<option value="spn"<%If strSearchType = "spn" Then Response.Write " SELECTED" End If%>>Spon Acct
														</select>&nbsp;<input type="text" name="searchval" <% If bc.browser = "Netscape" AND bc.version = "4" Then %>size="5"<%else%>size="10"<%end if%> value="<%=strSearchVal%>" class="navtxt" onclick="this.form.searchval.select();this.form.searchval.focus();">&nbsp;<input class="button" type="submit" value="Search" height="16">&nbsp;</td>
									</tr>
									<tr>
								      <td align="center" colspan="5"><img src="/images/whitedot.gif" width="600" height="2" border="0"></td>
								  	</tr>
								</table>
								<input type="hidden" name="curRep" value="<%=strCurRep%>">
								<input type="hidden" name="sort" id="sort" value="<%=Request.Form("sort")%>">
								<table BORDER="0" CELLSPACING="1" BORDERCOLOR="#000055" CELLPADDING="0" WIDTH="100%">
								  <tr>
									<td nowrap bgcolor="#000055" background="/images/000055.jpg" align="center" class="WhiteTxt">
										<a href="javascript:void(0);" onclick="document.getElementById('sort').value='rep,az'; return OnSubmitForm();"><img src="/images/sortdn.gif" width="15" height="10" border="0" alt="Sort by Rep#, Ascending"></a>
										<small><b>Rep#:</b></small>
										<a href="javascript:void(0);" onclick="document.getElementById('sort').value='rep,za'; return OnSubmitForm();"><img src="/images/sortup.gif" width="15" height="10" border="0" alt="Sort by Rep#, Descending"></a></td>
									<td nowrap bgcolor="#000055" background="/images/000055.jpg" align="center" class="WhiteTxt">
										<a href="javascript:void(0);" onclick="document.getElementById('sort').value='fund,az'; return OnSubmitForm();"><img src="/images/sortdn.gif" width="15" height="10" border="0" alt="Sort by Fund, Ascending"></a>
										<small><b>Fund:</b></small>
										<a href="javascript:void(0);" onclick="document.getElementById('sort').value='fund,za'; return OnSubmitForm();"><img src="/images/sortup.gif" width="15" height="10" border="0" alt="Sort by Fund, Descending"></a></td>
									<td nowrap bgcolor="#000055" background="/images/000055.jpg" background="/images/000055.jpg" align="center" class="WhiteTxt">
										<a href="javascript:void(0);" onclick="document.getElementById('sort').value='type,az'; return OnSubmitForm();"><img src="/images/sortdn.gif" width="15" height="10" border="0" alt="Sort by Account, Ascending"></a>
										<small><b>Type:</b></small>
										<a href="javascript:void(0);" onclick="document.getElementById('sort').value='type,za'; return OnSubmitForm();"><img src="/images/sortup.gif" width="15" height="10" border="0" alt="Sort by Account, Descending"></a></td>
									<td nowrap bgcolor="#000055" background="/images/000055.jpg" align="center" class="WhiteTxt">
										<a href="javascript:void(0);" onclick="document.getElementById('sort').value='cust,az'; return OnSubmitForm();"><img src="/images/sortdn.gif" width="15" height="10" border="0" alt="Sort by Customer, Ascending"></a>
										<small><b>Customer:</b></small>
										<a href="javascript:void(0);" onclick="document.getElementById('sort').value='cust,za'; return OnSubmitForm();"><img src="/images/sortup.gif" width="15" height="10" border="0" alt="Sort by Customer, Descending"></a></td>
									<td nowrap bgcolor="#000055" background="/images/000055.jpg" align="center" class="WhiteTxt">
										<a href="javascript:void(0);" onclick="document.getElementById('sort').value='inv,az'; return OnSubmitForm();"><img src="/images/sortdn.gif" width="15" height="10" border="0" alt="Sort by Investment, Ascending"></a>
										<small><b>Invest:</b></small>
										<a href="javascript:void(0);" onclick="document.getElementById('sort').value='inv,za'; return OnSubmitForm();"><img src="/images/sortup.gif" width="15" height="10" border="0" alt="Sort by Investment, Descending"></a></td>
									<td nowrap bgcolor="#000055" background="/images/000055.jpg" align="center" class="WhiteTxt">
										<a href="javascript:void(0);" onclick="document.getElementById('sort').value='comm,az'; return OnSubmitForm();"><img src="/images/sortdn.gif" width="15" height="10" border="0" alt="Sort by Total, Ascending"></a>
										<small><b>Total:</b></small>
										<a href="javascript:void(0);" onclick="document.getElementById('sort').value='comm,za'; return OnSubmitForm();"><img src="/images/sortup.gif" width="15" height="10" border="0" alt="Sort by Total, Descending"></a></td>
									<td nowrap bgcolor="#000055" background="/images/000055.jpg" align="center" class="WhiteTxt">
										<!--<a href="javascript:void(0);" onclick="document.getElementById('sort').value='tdt,az'; return OnSubmitForm();"><img src="/images/sortdn.gif" width="15" height="10" border="0" alt="Sort by Trade Date, Ascending"></a>-->
										<small><b>T-Date:</b></small>
										<!--<a href="javascript:void(0);" onclick="document.getElementById('sort').value='tdt,za'; return OnSubmitForm();"><img src="/images/sortup.gif" width="15" height="10" border="0" alt="Sort by Trade Date, Descending"></a>--></td>
									<td nowrap bgcolor="#000055" background="/images/000055.jpg" align="center" class="WhiteTxt">
										<a href="javascript:void(0);" onclick="document.getElementById('sort').value='spon,az'; return OnSubmitForm();"><img src="/images/sortdn.gif" width="15" height="10" border="0" alt="Sort by Spon Acct., Ascending"></a>
										<small><b>Spon Acct:</b></small>
										<a href="javascript:void(0);" onclick="document.getElementById('sort').value='spon,za'; return OnSubmitForm();"><img src="/images/sortup.gif" width="15" height="10" border="0" alt="Sort by Spon Acct., Descending"></a></td>
								  	<td nowrap bgcolor="#000055" background="/images/000055.jpg" align="center" class="WhiteTxt"><small><b>&nbsp;I/T:&nbsp;</b></small></td>
								</tr></form>
<%End If
	'Grab the records
	 Dim strSQL, arrDPProds, strBGround, intCount, a
	 Dim intRepTot, strRep
	 
'    strSQL = "SELECT * " &_
	
	
	'    strSQL = "SELECT vwDIRECT_PKG_PRODS_ADM.ID, vwDIRECT_PKG_PRODS_ADM.REPNUM, vwDIRECT_PKG_PRODS_ADM.FUND_NAME, vwDIRECT_PKG_PRODS_ADM.BATCH, " &_
	'			 "vwDIRECT_PKG_PRODS_ADM.CUSTOMER, vwDIRECT_PKG_PRODS_ADM.INVEST, vwDIRECT_PKG_PRODS_ADM.COMM, vwDIRECT_PKG_PRODS_ADM.TRADE_DATE, " &_
	'			 "vwDIRECT_PKG_PRODS_ADM.SPON_ACCT, vwDIRECT_PKG_PRODS_ADM.TYPE, vwDIRECT_PKG_PRODS_ADM.MONTH, vwDIRECT_PKG_PRODS_ADM.YEAR, " &_
	'			 "vwDIRECT_PKG_PRODS_ADM.lasalle_st_ID " &_
	'			 "FROM vwDIRECT_PKG_PRODS_ADM " &_
	'			 "WHERE ((vwDIRECT_PKG_PRODS_ADM.lasalle_st_ID='" & strREP_UID & "')" & Replace(strWhereEtc,"","") & ")" & strOrderBy
	'Else
	    strSQL = "SELECT vwDIRECT_PKG_PRODS.ID, vwDIRECT_PKG_PRODS.REPNUM, vwDIRECT_PKG_PRODS.FUND_NAME, vwDIRECT_PKG_PRODS.BATCH, " &_
				 "vwDIRECT_PKG_PRODS.CUSTOMER, vwDIRECT_PKG_PRODS.INVEST, vwDIRECT_PKG_PRODS.COMM, vwDIRECT_PKG_PRODS.TRADE_DATE, " &_
				 "vwDIRECT_PKG_PRODS.SPON_ACCT, vwDIRECT_PKG_PRODS.TYPE, vwDIRECT_PKG_PRODS.MONTH, vwDIRECT_PKG_PRODS.YEAR, " &_
				 "vwDIRECT_PKG_PRODS.lasalle_st_ID, vwDIRECT_PKG_PRODS.DPP_ADMIN " &_
				 "FROM vwDIRECT_PKG_PRODS " &_
				 "WHERE ((vwDIRECT_PKG_PRODS.lasalle_st_ID LIKE '" & strREP_UID & "')" & strWhereEtc & ")" & strOrderBy
	If blDPP_Admin_View = True Then
		'Special for Tim Meisenheimer
		If strREP_UID = "0KK003" Then
			strSQL = Replace(strSQL,"0KK003","0KK%")
		
		
		
		
		'Special for Pete Kearney
		ElseIf strREP_UID = "0KAA45" Then
			strSQL = Replace(strSQL,"0KAA45","0KAA45' OR vwDIRECT_PKG_PRODS.lasalle_st_ID LIKE '0KAA53' OR vwDIRECT_PKG_PRODS.lasalle_st_ID LIKE '0KAA64")
		
		
		
		
		
		Else	'NORMAL
			strSQL = Replace(strSQL,"vwDIRECT_PKG_PRODS","vwDIRECT_PKG_PRODS_ADM")
		End If
	End If
	
'response.write strSQL
			'Array details:
			' 0: ID
			' 1: REPNUM
			' 2: FUND_NAME
			' 3: BATCH
			' 4: CUSTOMER
			' 5: INVEST
			' 6: COMM
			' 7: TRADE_DATE
			' 8: SPON_ACCT
			' 9: TYPE
			'10: MONTH
			'11: YEAR
			'12: GOES_BY
			'13: lasalle_st_ID
			'14: DPP_ADMIN

	Set rst = conn.Execute(strSQL)
	
	If Not rst.EOF Then
		arrDPProds = rst.GetRows
		intCount = UBound(arrDPProds, 2)
	End If
	
	rst.Close
	Set rst = Nothing
	
	'Check for excel
	If Len(Request.Form("excel")) > 0  Then
		Call exportExcel()
	End If
	
	If Len(intCount) > 0 Then
		'First rep
		strRep = arrDPProds(1, 0)
		
		'Loop
		For i = 0 To UBound(arrDPProds, 2)
		  '
	 	  If strSortType = "cust" Then
		  	If Len(arrDPProds(4, i)) > 0 Then
		    	a = Asc(Left(arrDPProds(4, i),1))
		 		If a <> ii Then
				  Call Alpha()
				  strBGColor = "#ffffff"
		   		  strBGround = "/images/FFFFFF.jpg"
		 		End If
			Else
				a = 48
		 		If a <> ii Then
				  Call Alpha()
				  strBGColor = "#ffffff"
		   		  strBGround = "/images/FFFFFF.jpg"
		 		End If
			End If
	 	  End If 
			
			'Initialize or display rep total
			If strSortType = "rep" Then
				If strRep = arrDPProds(1, i) Then
					intRepTot = intRepTot + arrDPProds(6, i)
				Else
					'Display individual rep total%>
								  <tr>
									<td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="left" class="NavyTxtB" nowrap>&nbsp;<%=strRep%> Total:</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" nowrap align="right" class="NavyTxt">&nbsp;</td>
									<td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="right" class="NavyTxtB"><%If Not IsNull(arrDPProds(6, i)) Then Response.Write FormatCurrency(intRepTot) End If%>&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
									<td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
								  </tr>
<%					'Toggle bgcolor
					If strBGColor = "#ffffff" Then
					   	strBGColor = "#dedede"
					   	strBGround = "/images/DEDEDE.jpg"
					Else 
					   	strBGColor = "#ffffff"
					   	strBGround = "/images/FFFFFF.jpg"
					End If
					
					'
					intRepTot = arrDPProds(6, i)
					strRep = arrDPProds(1, i)
				End If
			End If%>
								  <tr>
									<td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="left" class="NavyTxt">&nbsp;<%=arrDPProds(1, i)%>&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt"><%=arrDPProds(2, i)%>&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt"><%=arrDPProds(3, i)%>&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt"><%=arrDPProds(4, i)%>&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" nowrap align="right" class="NavyTxt"><%If Not IsNull(arrDPProds(5, i)) Then Response.Write FormatCurrency(arrDPProds(5, i)) End If%>&nbsp;</td>
									<td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="right" class="NavyTxt"><%If Not IsNull(arrDPProds(6, i)) Then Response.Write FormatCurrency(arrDPProds(6, i)) End If%>&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt"><%=arrDPProds(7, i)%>&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt"><%=arrDPProds(8, i)%>&nbsp;</td>
									<td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt"><%=arrDPProds(9, i)%></td>
								  </tr>
<%		  	'Update running total
			If Not IsNull(arrDPProds(6, i)) Then
				intTotal = intTotal + arrDPProds(6, i)
			End If
			
			intRecords = intRecords + 1
			strLastName = arrDPProds(0, i)
		  	If strBGColor = "#ffffff" Then
			   	strBGColor = "#dedede"
			   	strBGround = "/images/DEDEDE.jpg"
			Else 
			   	strBGColor = "#ffffff"
			   	strBGround = "/images/FFFFFF.jpg"
			End If
		Next
 	End If
	
	'Last rep subtotal
	If strSortType = "rep" Then %>
								<tr>
									<td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="left" class="NavyTxtB" nowrap>&nbsp;<%=strRep%> Total:</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" nowrap align="right" class="NavyTxt">&nbsp;</td>
									<td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="right" class="NavyTxtB"><%Response.Write FormatCurrency(intRepTot)%>&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
									<td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
								  </tr>
<%	End If%>
								  <tr>
									<td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="left" class="NavyTxtB">&nbsp;Total:</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" nowrap align="right" class="NavyTxt">&nbsp;</td>
									<td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="right" class="NavyTxtB"><%=FormatCurrency(intTotal)%>&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
								    <td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
									<td bgcolor="<%=strBGColor%>" background="<%=strBGround%>" align="center" class="NavyTxt">&nbsp;</td>
								  </tr>
								</table>
							</td>
						</tr>
					</table>
				</td>
			</tr>
			<tr><td align="center"><%
		If intRecords = 0 Then
		 	response.write "<span class='AlertTxt'>Sorry, no records were found for selected criteria. Please try your search again.</span><br>"
		End If %></td></tr></table>
					<!-- //End Body Content --></td>
					</td>
				<td width="5"><IMG SRC="/images/transparent.gif" WIDTH="7" HEIGHT="7" BORDER="0" ALT=""></td>
			</tr>
		</table></td>
	</tr>
</table>
</DIV>
<%'Response.Flush%>
</body>
</html>
<!-- #include virtual="/inc/WhichBrowser.asp" -->
<%

Set conn = Nothing
'*** SUBROUTINES ***

Sub Alpha()
	'response.write strDirection & " " & a & " " & chr(a)
 	If LCase(strDirection) = "asc" Then
		c = 65
		ce = 90
		strStep = 1
	ElseIf LCase(strDirection) = "desc" Then
		c = 90
		ce = 65
		strStep = -1
	End If
	Response.write "<tr>"
	Response.write "<td nowrap align='center' colspan='9' background='/images/lightBlueBG.gif' style='border-bottom: 1px rgb(050,050,050); font-family: Arial; font-size: 10px; font-weight: bold; color: #ffffff'>"
	Response.write "<a style='color: #000055;' href='#top'>Top</a>"
		While c <> ce + strStep
			If c = a Then
				Response.write "<strong>&nbsp;|&nbsp;</strong><a style='color: #0000dd;' name='" & Chr(c) & "'><big>" & Chr(c) & "</big></a>"
			Else
				Response.write "<strong>&nbsp;|&nbsp;</strong><a style='color: #000055;' href='#" & Chr(c) & "'>" & Chr(c) & "</a>"
			End If
			c = c + strStep
		Wend
	Response.write "</td>"
	Response.write "</tr>"
	ii = a
End Sub

Sub SelectRep()

'response.write strSQL
			'Array details:
			' 0: lasalle_st_ID
			' 1: LASL_ACTIVCODE
			' 2: SHARED_REP_NO
			' 3: Description
			' 4: Share_Pcnt

	strSelectList =  ""
	intRepCount = 0

	If blDPP_Admin_View = True AND strREP_UID <> "0KK003" AND strREP_UID <> "0KAA45" Then
		strSQLr = "SELECT T_E_Services.lasalle_st_ID, vwREPALL.LASL_ACTIVCODE, DIRECT_PKG_PRODS_REP_LIST.[Rep Number], 'ADMIN' AS Description, " &_
				  "DIRECT_PKG_PRODS_REP_LIST.Percentage " &_
				  "FROM T_E_Services INNER JOIN " &_
                  "vwREPALL ON T_E_Services.ID = vwREPALL.ID INNER JOIN " &_
                  "DIRECT_PKG_PRODS_REP_LIST ON vwREPALL.LASL_REP_NO = DIRECT_PKG_PRODS_REP_LIST.[Rep Code] " &_
				  "WHERE vwREPALL.DPP_ADMIN = 1 AND T_E_Services.lasalle_st_ID LIKE '" & strREP_UID & "' " &_
				  "ORDER BY DIRECT_PKG_PRODS_REP_LIST.[Rep Number]"
	Else
		strSQLr = "SELECT T_E_Services.lasalle_st_ID, vwREPALL.LASL_ACTIVCODE, T_SUB_RRs.SHARED_REP_NO, T_SUB_RRs.Description, T_SUB_RRs.Share_Pcnt " &_
				  "FROM (T_E_Services INNER JOIN vwREPALL ON T_E_Services.ID = vwREPALL.ID) INNER JOIN T_SUB_RRs ON vwREPALL.ID = T_SUB_RRs.ID " &_
				  "WHERE (((T_E_Services.lasalle_st_ID) LIKE '" & strREP_UID & "') AND ((vwREPALL.LASL_ACTIVCODE)='active') AND (T_SUB_RRs.Share_Pcnt > 0) " &_
				  "AND (T_SUB_RRs.Description Not Like 'Direct')) " &_
				  "ORDER BY T_SUB_RRs.SHARED_REP_NO"
		
		'Special for Tim Meisenheimer
		If blDPP_Admin_View = True AND strREP_UID = "0KK003" Then
			strSQLr = Replace(strSQLr,"0KK003","0KK%")
		End If
		
		'Special for Pete Kearney
		If blDPP_Admin_View = True AND strREP_UID = "0KAA45" Then
			strSQLr = Replace(strSQLr,"0KAA45","0KAA45' OR T_E_Services.lasalle_st_ID LIKE '0KAA53' OR T_E_Services.lasalle_st_ID LIKE '0KAA64")
		End If
	End If
	
	Set rsr = conn.Execute(strSQLr)
	If Not rsr.EOF Then
		'response.write "go"
		arrRepList = rsr.GetRows
		'response.write UBound(arrRepList, 2)
	End If
	
	rsr.Close
	Set rsr = Nothing
	
	strSelectList = ""
'	  response.write arrRepList(4,i)
	Response.Write "<select name=""repnum"" class=""NavTxt"" onchange=""document.pressed=this.value;return OnSubmitForm();"">" & VbCrLf

	If IsArray(arrRepList) Then
	  For i = 0 to UBound(arrRepList, 2)
		
		If LCase(arrRepList(2,i)) = LCase(strRepnum) Then
			strSelectList = strSelectList & "	<option value=""" & arrRepList(2,i) & """ SELECTED>" & arrRepList(2,i) & "&nbsp;(" & arrRepList(3,i) & "/"
			
			'Display f'd splits
			Select Case CInt(arrRepList(4,i))
				Case 13
					strSelectList = strSelectList & "13.333"
				Case 33
					strSelectList = strSelectList & "33.333"
				Case Else
					strSelectList = strSelectList & arrRepList(4,i)
			End Select
			
			strSelectList = strSelectList & "%)</option>" & vbcrlf
		Else 
			strSelectList = strSelectList & "	<option value=""" & arrRepList(2,i) & """>" & arrRepList(2,i) & "&nbsp;(" & arrRepList(3,i) & "/"
			
			'Display f'd splits
			Select Case CInt(arrRepList(4,i))
				Case 13
					strSelectList = strSelectList & "13.333"
				Case 33
					strSelectList = strSelectList & "33.333"
				Case Else
					strSelectList = strSelectList & arrRepList(4,i)
			End Select
			
			strSelectList = strSelectList & "%)</option>" & vbcrlf
		End If
		
	  Next

	  If UBound(arrRepList, 2) > 0 Then
	  	If strRepnum = "all" Then
			Response.Write "	<option value=""all"" selected>All</option>" & VbCrLf & strSelectList
		Else
			Response.Write "	<option value=""all"">All</option>" & VbCrLf & strSelectList
		End If
		Response.Write "</select>" & vbcrlf
	  Else
		Response.Write strSelectList & vbcrlf & "</select>" & vbcrlf
	  End If
		'response.write strTEMP
	
	End If
End Sub

Sub WhoRU(sup,rep)
	'response.write sup & " - " & rep
	'Create recordset
	Set rst = Server.CreateObject("ADODB.Recordset")
	
	'SQL statement
	If Left(Request.ServerVariables("REMOTE_ADDR"),8) = "10.1.75." OR Left(Request.ServerVariables("REMOTE_ADDR"),8) = "10.1.1.9" Then
		Select Case LCase(Request.ServerVariables("AUTH_USER"))
			Case "bkn002","bkn001","0ka411","0ka755","0ka111"
				strSQL = "SELECT vwRepSupervisors.REP_ID, vwRepSupervisors.REP_LASTNAME, vwRepSupervisors.REP_NAME, vwRepSupervisors.REP_NO, " &_
						 "vwRepSupervisors.REP_LSS_ID, vwRepSupervisors.SUPERVISOR_ID, vwRepSupervisors.SUPERVISOR_NAME, " &_
						 "vwRepSupervisors.lasalle_st_ID, vwRepSupervisors.DPP_ADMIN " &_
						 "FROM vwRepSupervisors " &_
						 "WHERE vwRepSupervisors.lasalle_st_ID = '" & sup & "' " &_
						 "ORDER BY vwRepSupervisors.REP_LASTNAME, vwRepSupervisors.REP_NAME"
			Case Else
				strSQL = "SELECT vwRep.REP_ID, vwRep.REP_LASTNAME, vwRep.REP_NAME, vwRep.REP_NO, vwRep.REP_LSS_ID, " &_
						 "NULL, NULL, vwRep.REP_LSS_ID, vwRep.DPP_ADMIN " &_
						 "FROM vwRep " &_
						 "ORDER BY vwRep.REP_LASTNAME, vwRep.REP_NAME"
		End Select
	Else
		strSQL = "SELECT vwRepSupervisors.REP_ID, vwRepSupervisors.REP_LASTNAME, vwRepSupervisors.REP_NAME, vwRepSupervisors.REP_NO, " &_
				 "vwRepSupervisors.REP_LSS_ID, vwRepSupervisors.SUPERVISOR_ID, vwRepSupervisors.SUPERVISOR_NAME, " &_
				 "vwRepSupervisors.lasalle_st_ID, vwRepSupervisors.DPP_ADMIN " &_
				 "FROM vwRepSupervisors " &_
				 "WHERE vwRepSupervisors.lasalle_st_ID = '" & sup & "' " &_
				 "ORDER BY vwRepSupervisors.REP_LASTNAME, vwRepSupervisors.REP_NAME"
	End If
	'If Left(Request.ServerVariables("REMOTE_ADDR"),8) = "10.1.75." Then
	'	response.write strsql
	'End If
	'Execute SQL
	Set rst = conn.Execute(strSQL)
	
	'Populate array
	If Not rst.EOF Then
		arrWho = rst.GetRows
	
		'Clean up
		If IsObject(rst) Then
			rst.Close
			Set rst = Nothing
		End If
		
		'Array
		'0 REP_ID
		'1 REP_LASTNAME
		'2 REP_NAME
		'3 REP_NO
		'4 REP_LSS_ID
		'5 SUPERVISOR_ID
		'6 SUPERVISOR_NAME
		'7 lasalle_st_ID
		'8 DPP_ADMIN
		
		'Loop
		'response.write Len(arrWho)
		If IsArray(arrWho) Then
			If UBound(arrWho, 2) > -1 Then
				'Build form
				Response.Write "		Select Rep: <select class=""NavyTxtB"" name=""rep"" onchange=""document.reps.repnum.value='all';return OnSubmitForm();"">" & VbCrLf
				
				'First the 'Supervisor'
				strDPP_Admin = arrWho(6, 0)
				strSelRep = strSelRep & "				<option "
				
				If Left(Request.ServerVariables("REMOTE_ADDR"),8) <> "10.1.75." Then
					If rep = arrWho(7, 0) AND blDPP_Admin_View <> True Then
						strSelRep = strSelRep & "SELECTED "
					End If
					strSelRep = strSelRep & "value=""" & arrWho(7, 0) & """>" & arrWho(6, 0) & " / " & UCase(arrWho(7, 0)) & "</option>" & VbCrLf
				Else
					strSelRep = strSelRep & "value="""">Pick a Rep...</option>" & VbCrLf
				End If
				
				'Now underlings
				For i = 0 To UBound(arrWho ,2)
					strSelRep = strSelRep & "			<option "
					If rep = arrWho(4, i) AND blDPP_Admin_View <> True Then
						strSelRep = strSelRep & "SELECTED "
					End If
					
					strSelRep = strSelRep & "value=""" & arrWho(4, i) & """>" & arrWho(2, i) & " / " & UCase(arrWho(4, i)) & "</option>" & VbCrLf
					
					'Show additional admin records
					If arrWho(8, i) = True AND Left(Request.ServerVariables("REMOTE_ADDR"),8) = "10.1.75." Then
						If Len(Request.Form("rep")) > 0 Then
							If (LCase(Right(Request.Form("rep"),Len(Request.Form("rep"))-5)) = LCase(arrWho(4, i))) = True Then
								strSelRep = strSelRep & "			<option SELECTED value=""admin" & arrWho(4, i) & """>" & arrWho(2, i) & " / " & "Admin" & "</option>" & VbCrLf
							Else
								strSelRep = strSelRep & "			<option value=""admin" & arrWho(4, i) & """>" & arrWho(2, i) & " / " & "Admin" & "</option>" & VbCrLf
							End If
						Else
							strSelRep = strSelRep & "			<option value=""admin" & arrWho(4, i) & """>" & arrWho(2, i) & " / " & "Admin" & "</option>" & VbCrLf
						End If
					End If
					'Show additional admin records
					'If arrWho(8, i) = True AND Left(Request.ServerVariables("REMOTE_ADDR"),8) = "10.1.75." Then
					'	If LCase(Left(Request.Form("rep"),5)) <> "admin" Then
					'		strSelRep = strSelRep & "				<option value=""Admin""" & arrWho(4, i) & """>" & arrWho(2, i) & " / Admin</option>" & VbCrLf & strSelRep
					'	Else
					'		strSelRep = strSelRep & "				<option SELECTED value=""Admin""" & arrWho(4, i) & """>" & arrWho(2, i) & " / Admin</option>" & VbCrLf & strSelRep
					'	End If
					'End If
					
				Next
				
				'Admin Row
				If blDPP_Admin = True AND Left(Request.ServerVariables("REMOTE_ADDR"),8) <> "10.1.75." Then
					If LCase(Request.Form("rep")) <> "admin" Then
						strSelRep = "				<option value=""Admin"">" & strDPP_Admin & " / Admin</option>" & VbCrLf & strSelRep
					Else
						strSelRep = "				<option SELECTED value=""Admin"">" & strDPP_Admin & " / Admin</option>" & VbCrLf & strSelRep
					End If
				End If
				
				Response.Write strSelRep
				
				'Close form & row
				Response.Write "			</select>" & VbCrLf
			End If
		End If
	End If
End Sub

Sub exportExcel()
	'
	Dim nRandom
	Dim fileExcel
	Dim filePath
	Dim filename
	Dim fs
	Dim MyFile
	Dim strLine
	Dim ii
	Dim seperator
	
	'Create a randome Filename
	Randomize
    nRandom = Int((90 - 1 + 10) * Rnd + 10)
    fileExcel = UCase(strREP_UID) & "_Directs_" & CStr(nRandom) & ".csv"
	
    'Virtual directory name or just the slash if it is at the wwwroot.
    filePath= Server.mapPath("\Reports\" & strREP_UID)
    filename=filePath & "\" & fileExcel
	
    'Create the File with extension .xls using the FileSytemObject
    'If the file does not exist, the TRUE parameter will allow it
    'to be created. Make sure the user* impersonated has write
    'permissions to the directory where the file is being created.
	
	'Initialize Excel file
    Set fs = Server.CreateObject("Scripting.FileSystemObject")
    Set MyFile = fs.CreateTextFile(filename, True)
	
	strLine = strLine & """Rep#"","
	strLine = strLine & """Fund"","
	strLine = strLine & """Type"","
	strLine = strLine & """Customer"","
	strLine = strLine & """Invest"","
	strLine = strLine & """Total"","
	strLine = strLine & """T-Date"","
	strLine = strLine & """Spon Acct"","
	strLine = strLine & """I/T"""
		
	MyFile.writeline strLine
	
	'Retrieve the values from the array and write into the file
	For i = 0 To Ubound(arrDPProds, 2)
		seperator = ""
        strLine = "" 'Initialize the variable for storing the data
		'MyFile.WriteLine("<tr>")
		For ii = 1 To 9
			strLine = strLine & seperator & """" & arrDPProds(ii, i) & """"
			seperator = ","
		Next
		MyFile.writeline strLine
	Next
	
	
	'Clean up
	MyFile.Close
	Set MyFile=Nothing
	
	'Show a link to the Excel File.
	Response.Write "<div align=""center""><A href=/Reports/"  & strREP_UID & "/" & fileExcel & " style=""font-size:14px;font-weight:bold;"">Click to open to Excel file, or right-click and choose 'Save Link (or Target) As...' to save it</a></div>"
		
	exit sub
	'Open...
	MyFile.WriteLine("<html><body>")
	MyFile.WriteLine("<table border=""1"">")
	MyFile.WriteLine("<tr>")
	
	'Column headings
	strLine = "" 'Initialize the variable for storing the filednames
	strLine = strLine & "<th nowrap>Rep#</th>"
	strLine = strLine & "<th nowrap>Fund</th>"
	strLine = strLine & "<th nowrap>Type</th>"
	strLine = strLine & "<th nowrap>Customer</th>"
	strLine = strLine & "<th nowrap>Invest</th>"
	strLine = strLine & "<th nowrap>Total</th>"
	strLine = strLine & "<th nowrap>T-Date</th>"
	strLine = strLine & "<th nowrap>Spon Acct</th>"
	strLine = strLine & "<th nowrap>I/T</th>"
	strLine = strLine & "</tr>"
	
	'Write this string into the file
	MyFile.writeline strLine
	
	'Retrieve the values from the array and write into the file
	For i = 0 To Ubound(arrDPProds, 2)
        'strLine = "" 'Initialize the variable for storing the data
		MyFile.WriteLine("<tr>")
		For ii = 1 To 9
			MyFile.writeline("<td align=""Left"" nowrap>" & arrDPProds(ii, i) & "</td>")
		Next
		'MyFile.writeline strLine
	Next
	
	MyFile.WriteLine("</table></body></html>")
	MyFile.Close
	
	'Show a link to the Excel File.
	Response.Write "<div align=""center""><A href=/Reports/"  & strREP_UID & "/" & fileExcel & " style=""font-size:14px;font-weight:bold;"">Click to open to Excel file, or right-click and choose 'Save Link (or Target) As...' to save it</a></div>"
	
End Sub
%>