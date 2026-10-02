///For SMTPServerConfig()

function SMTPServerConfigValidation() {
    var errMsg = "";

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtSMTPServer', "ctl00_ContentPlaceHolder1_spanErrLogin", "SMTP Server is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtSMTPServerPort', "ctl00_ContentPlaceHolder1_spanErrLogin", "SMTP Server Port is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtUserName', "ctl00_ContentPlaceHolder1_spanErrLogin", "User Name is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtPassword', "ctl00_ContentPlaceHolder1_spanErrLogin", "Password is required field"));
        
    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtFromMailId', "ctl00_ContentPlaceHolder1_spanErrLogin", "From Mail Id is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (emailValidation('ctl00_ContentPlaceHolder1_txtFromMailId', "ctl00_ContentPlaceHolder1_spanErrLogin"));

               
     return throwErr(errMsg,"ctl00_ContentPlaceHolder1_divErrLogin");

}

///For ChangePasswordValidation()

function ChangePasswordValidation() {
    var errMsg = "";

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtOldPassword', "ctl00_ContentPlaceHolder1_spanErrLogin", "Old Password is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtNewPassword', "ctl00_ContentPlaceHolder1_spanErrLogin", "New Password is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (ChkPasswordRules('ctl00_ContentPlaceHolder1_txtNewPassword', "ctl00_ContentPlaceHolder1_spanErrLogin"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtConfirmPassword', "ctl00_ContentPlaceHolder1_spanErrLogin", "Confirm Password is required field"));
        
    if (errMsg.length <= 0)    
        errMsg = errMsg + (confirmValidation('ctl00_ContentPlaceHolder1_txtNewPassword', "ctl00_ContentPlaceHolder1_txtConfirmPassword", "ctl00_ContentPlaceHolder1_spanErrLogin"));
               
     return throwErr(errMsg,"ctl00_ContentPlaceHolder1_divErrLogin");

}

///For AgendaValidation()

function AgendaValidation() {
    var errMsg = "";

    if (errMsg.length <= 0) 
        errMsg = errMsg + (zeroValidation('ctl00_ContentPlaceHolder1_ddlSubjectType', "ctl00_ContentPlaceHolder1_spanErrLogin", "Subject Type is required field"));

    if (errMsg.length <= 0) 
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtShortText', "ctl00_ContentPlaceHolder1_spanErrLogin", "Short Text is required field"));
        
    window.scrollTo(0,0);          
               
    var msg = errMsg.toString();

    if (msg.length <= 0) {
        document.getElementById('divProgress').style.visibility = 'visible';
    }
    else {
        document.getElementById('divProgress').style.visibility = 'hidden';
    }
           
    return throwErr(errMsg,"ctl00_ContentPlaceHolder1_divErrLogin");

}

///For MeetingMemberValidation()

function MeetingMemberValidation() {
    var errMsg = "";

    if (errMsg.length <= 0) 
        errMsg = errMsg + (zeroValidation('ctl00_ContentPlaceHolder1_ddlCommittee', "ctl00_ContentPlaceHolder1_spanErrLogin", "Committee Name is required field"));

    if (errMsg.length <= 0) 
        errMsg = errMsg + (zeroValidation('ctl00_ContentPlaceHolder1_ddlMeeting', "ctl00_ContentPlaceHolder1_spanErrLogin", "Meeting No is required field"));
                      
     return throwErr(errMsg,"ctl00_ContentPlaceHolder1_divErrLogin");

}

///For MeetingMemberEditValidation()

function MeetingMemberEditValidation() {
    var errMsg = "";

    if (errMsg.length <= 0) 
        errMsg = errMsg + (zeroValidation('ctl00_ContentPlaceHolder1_ddlMemberName', "ctl00_ContentPlaceHolder1_spanErrLogin", "Member Name is required field"));

    if (errMsg.length <= 0) 
        errMsg = errMsg + (zeroValidation('ctl00_ContentPlaceHolder1_ddlMemberType', "ctl00_ContentPlaceHolder1_spanErrLogin", "Member Type is required field"));
                      
     return throwErr(errMsg,"ctl00_ContentPlaceHolder1_divErrLogin");

}

///For MeetingValidation()

function MeetingValidation() {
    var errMsg = "";

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtPlace', "ctl00_ContentPlaceHolder1_spanErrLogin", "Place is required field"));
     
    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtVenue', "ctl00_ContentPlaceHolder1_spanErrLogin", "Venue is required field"));
        
    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtMeetingDate', "ctl00_ContentPlaceHolder1_spanErrLogin", "Meeting Date is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtMeetingTime', "ctl00_ContentPlaceHolder1_spanErrLogin", "Meeting Time is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtAgendaSubmissionDate', "ctl00_ContentPlaceHolder1_spanErrLogin", "Agenda Submission Date is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtColor', "ctl00_ContentPlaceHolder1_spanErrLogin", "Meeting Color Code is required field"));

                      
     return throwErr(errMsg,"ctl00_ContentPlaceHolder1_divErrLogin");

}
///For CommitteeMemberValidation()

function CommitteeMemberValidation() {
    var errMsg = "";

    if (errMsg.length <= 0) 
        errMsg = errMsg + (zeroValidation('ctl00_ContentPlaceHolder1_ddlMemberName', "ctl00_ContentPlaceHolder1_spanErrLogin", "Member name is required field"));

    if (errMsg.length <= 0) 
        errMsg = errMsg + (zeroValidation('ctl00_ContentPlaceHolder1_ddlMemberType', "ctl00_ContentPlaceHolder1_spanErrLogin", "Member type is required field"));
      
    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtAppointmentDate', "ctl00_ContentPlaceHolder1_spanErrLogin", "Appointment date is required field"));
                              
     return throwErr(errMsg,"ctl00_ContentPlaceHolder1_divErrLogin");

}

///For CommitteeValidation()

function CommitteeValidation() {
    var errMsg = "";

    if (errMsg.length <= 0) 
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtCommitteeName', "ctl00_ContentPlaceHolder1_spanErrLogin", "Committee name is required field"));
      
    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtIncorporationDate', "ctl00_ContentPlaceHolder1_spanErrLogin", "Incorporation date is required field"));
              
    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtMeetingStartNo', "ctl00_ContentPlaceHolder1_spanErrLogin", "Meeting starting no is required field"));
              
     return throwErr(errMsg,"ctl00_ContentPlaceHolder1_divErrLogin");

}


///For MemberValidation()

function MemberValidation() {
    var errMsg = "";

    if (errMsg.length <= 0) 
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtMemberName', "ctl00_ContentPlaceHolder1_spanErrLogin", "Member name is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (zeroValidation('ctl00_ContentPlaceHolder1_ddlSex', "ctl00_ContentPlaceHolder1_spanErrLogin", "Sex is required field"));
      
    if (errMsg.length <= 0)    
        errMsg = errMsg + (zeroValidation('ctl00_ContentPlaceHolder1_ddlDesignation', "ctl00_ContentPlaceHolder1_spanErrLogin", "Designation name is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtDOB', "ctl00_ContentPlaceHolder1_spanErrLogin", "Date of birth is required field"));
    
    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtDOJ', "ctl00_ContentPlaceHolder1_spanErrLogin", "Date of join is required field"));
                  
    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtEmailId', "ctl00_ContentPlaceHolder1_spanErrLogin", "Email id is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (emailValidation('ctl00_ContentPlaceHolder1_txtEmailId', "ctl00_ContentPlaceHolder1_spanErrLogin"));
               
     return throwErr(errMsg,"ctl00_ContentPlaceHolder1_divErrLogin");

}

///For UserValidation()

function UserValidation() {
    var errMsg = "";

    if (errMsg.length <= 0) 
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtUserName', "ctl00_ContentPlaceHolder1_spanErrLogin", "User Name is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (zeroValidation('ctl00_ContentPlaceHolder1_ddlDepartment', "ctl00_ContentPlaceHolder1_spanErrLogin", "Department Name is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (zeroValidation('ctl00_ContentPlaceHolder1_ddlRole', "ctl00_ContentPlaceHolder1_spanErrLogin", "Role Name is required field"));
       
    if (errMsg.length <= 0)    
        errMsg = errMsg + (zeroValidation('ctl00_ContentPlaceHolder1_ddlDesignation', "ctl00_ContentPlaceHolder1_spanErrLogin", "Designation Name is required field"));
        
    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtEmailId', "ctl00_ContentPlaceHolder1_spanErrLogin", "EmailId is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (emailValidation('ctl00_ContentPlaceHolder1_txtEmailId', "ctl00_ContentPlaceHolder1_spanErrLogin"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtLoginName', "ctl00_ContentPlaceHolder1_spanErrLogin", "LoginName is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtPassword', "ctl00_ContentPlaceHolder1_spanErrLogin", "Password is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (ChkPasswordRules('ctl00_ContentPlaceHolder1_txtPassword', "ctl00_ContentPlaceHolder1_spanErrLogin"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtConfirmPassword', "ctl00_ContentPlaceHolder1_spanErrLogin", "Confirm Password is required field"));
        
    if (errMsg.length <= 0)    
        errMsg = errMsg + (confirmValidation('ctl00_ContentPlaceHolder1_txtPassword', "ctl00_ContentPlaceHolder1_txtConfirmPassword", "ctl00_ContentPlaceHolder1_spanErrLogin"));

//function confirmValidation(controlId1, controlId2, errId) {
                
     return throwErr(errMsg,"ctl00_ContentPlaceHolder1_divErrLogin");

}


///For Designation

function DesignationValidation() {
    var errMsg = "";

    if (errMsg.length <= 0) 
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtDesignationCode', "ctl00_ContentPlaceHolder1_spanErrLogin", "Designation Code is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtDesignationName', "ctl00_ContentPlaceHolder1_spanErrLogin", "Designation Name is required field"));

     return throwErr(errMsg,"ctl00_ContentPlaceHolder1_divErrLogin");

}

///For DecisionType

function DecisionTypeValidation() {
    var errMsg = "";

    if (errMsg.length <= 0) 
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtDecisionTypeCode', "ctl00_ContentPlaceHolder1_spanErrLogin", "Decision Type Code is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtDecisionTypeName', "ctl00_ContentPlaceHolder1_spanErrLogin", "Decision Type Name is required field"));

     return throwErr(errMsg,"ctl00_ContentPlaceHolder1_divErrLogin");

}

///For SubjectType

function SubjectTypeValidation() {
    var errMsg = "";

    if (errMsg.length <= 0) 
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtSubjectTypeCode', "ctl00_ContentPlaceHolder1_spanErrLogin", "Subject Type Code is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtSubjectTypeName', "ctl00_ContentPlaceHolder1_spanErrLogin", "Subject Type Name is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtOrderNo', "ctl00_ContentPlaceHolder1_spanErrLogin", "Display Order is required field"));

     return throwErr(errMsg,"ctl00_ContentPlaceHolder1_divErrLogin");

}

///For MemberType

function MemberTypeValidation() {
    var errMsg = "";

    if (errMsg.length <= 0) 
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtMemberTypeCode', "ctl00_ContentPlaceHolder1_spanErrLogin", "Member Type Code is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtMemberTypeName', "ctl00_ContentPlaceHolder1_spanErrLogin", "Member Type Name is required field"));

     return throwErr(errMsg,"ctl00_ContentPlaceHolder1_divErrLogin");

}

///For Department

function DeptValidation() {
    var errMsg = "";

    if (errMsg.length <= 0) 
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtDeptCode', "ctl00_ContentPlaceHolder1_spanErrLogin", "Department Code is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtDeptName', "ctl00_ContentPlaceHolder1_spanErrLogin", "Department Name is required field"));

    if (errMsg.length <= 0)    
        errMsg = errMsg + (nullValidation('ctl00_ContentPlaceHolder1_txtOrderNo', "ctl00_ContentPlaceHolder1_spanErrLogin", "Display Order is required field"));

     return throwErr(errMsg,"ctl00_ContentPlaceHolder1_divErrLogin");

}

///For Login Page

function LoginValidation() {
    var errMsg = "";

    if (errMsg.length <= 0) 
     {   
        errMsg = errMsg + (nullValidation('txtLoginName', "spanErrLogin", "UserName is required field"));
     }
    if (errMsg.length <= 0)    
     {
        errMsg = errMsg + (nullValidation('txtPassword', "spanErrLogin", "Password is required field"));
     }

     return throwErr(errMsg,"divErrLogin");

}

///throwErr

function throwErr(errMsg, divErrId) {
    var msg = errMsg.toString();

    var err;

    if (msg.length <= 0) {
        document.getElementById(divErrId).className = "divErrorHide";
        err = true;
    }
    else {
        document.getElementById(divErrId).className = "divError";
        err = false;
    }
    //alert (err);
    return err;
}


//Null Validation
function nullValidation(controlId, errId, alertMsg) {

    var chkText = document.getElementById(controlId).value;

    var newString = Trim(chkText);

    //alert("1" + newString + "1");

    if (newString == "" || newString == "." || newString == ".." || newString == "..." || newString == "....") {

        document.getElementById(errId).innerHTML = alertMsg;
        document.getElementById(controlId).focus();
        document.getElementById(controlId).className = "skinNormalValidationText";

        return "null";
    }
    else {
        return "";
    }

}
//zeroValidation
function zeroValidation(controlId, errId, alertMsg) {


    var chkText = document.getElementById(controlId).value;

    var newString = Trim(chkText);

    //alert("1" + newString + "1");

    if (newString == 0) {

        document.getElementById(errId).innerHTML = alertMsg;
        document.getElementById(controlId).focus();
        document.getElementById(controlId).className = "skinNormalValidationText";

        return "0";
    }
    else {
        return "";
    }

}

///String Validation

function StringValidation(controlId, errId) {


    var ValidChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHILJKLMNOPQRSTUVWXYZ .,";
    var Char;
    var chkStatus = true;
    var sText = document.getElementById(controlId).value;
    for (i = 0; i < sText.length; i++) {
        Char = sText.charAt(i);
        if (ValidChars.indexOf(Char) == -1) {
            chkStatus = false;
        }
    }
    if (chkStatus == false) {
        document.getElementById(controlId).focus();
        document.getElementById(controlId).className = "skinNormalValidationText";
        document.getElementById(errId).innerHTML = "Alphabets only allowed";
        //alert("Alphabets only allowed");
        return "string";
    }
    else {
        return "";
    }
}

//AlphaNumeric Validation 
function AlphaNumericValidation(controlId, errId) {



    var ValidChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHILJKLMNOPQRSTUVWXYZ 1234567890.,-";
    var Char;
    var chkStatus = true;
    var sText = document.getElementById(controlId).value;
    for (i = 0; i < sText.length; i++) {
        Char = sText.charAt(i);
        if (ValidChars.indexOf(Char) == -1) {
            chkStatus = false;
        }
    }
    if (chkStatus == false) {
        document.getElementById(controlId).focus();
        document.getElementById(controlId).className = "skinNormalValidationText";
        document.getElementById(errId).innerHTML = "Alphabets & Numbers only allowed";
        //alert("Alphabets & Numbers only allowed");
        return "alpha";
    }
    else {
        return "";
    }
}


//AlphaNumeric Validation  and specialcharacter
function AlphaNumericspecialcharValidation(controlId, errId) {



    var ValidChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHILJKLMNOPQRSTUVWXYZ 1234567890.,#@%&$()+*&-";
    var Char;
    var chkStatus = true;
    var sText = document.getElementById(controlId).value;
    for (i = 0; i < sText.length; i++) {
        Char = sText.charAt(i);
        if (ValidChars.indexOf(Char) == -1) {
            chkStatus = false;
        }
    }
    if (chkStatus == false) {
        document.getElementById(controlId).focus();
        document.getElementById(controlId).className = "skinNormalValidationText";
        document.getElementById(errId).innerHTML = "Alphabets & Numbers & Special Character only allowed";
        //alert("Alphabets & Numbers only allowed");
        return "alpha";
    }
    else {
        return "";
    }
}


//Number Validation

function NumberValidation(controlId, errId) {

    var ValidChars = "1234567890 ";
    var Char;
    var chkStatus = true;
    var sText = document.getElementById(controlId).value;
    for (i = 0; i < sText.length; i++) {
        Char = sText.charAt(i);
        if (ValidChars.indexOf(Char) == -1) {
            chkStatus = false;
        }
    }
    if (chkStatus == false) {
        document.getElementById(controlId).focus();
        document.getElementById(controlId).className = "skinNormalValidationText";
        document.getElementById(errId).innerHTML = "Numbers only allowed";
        //alert("Numbers only allowed");
        return "number";
    }
    else {
        return "";
    }
}

//ChkPasswordRules

// sees if a password contains one of a set of characters
function contains(password, validChars) {

    for (i = 0; i < password.length; i++) {
        var char = password.charAt(i);
        if (validChars.indexOf(char) > -1) {
            return true;
        }
    }

    return false;

}
function ChkPasswordRules(controlId, errId) {

    var password = document.getElementById(controlId).value;
    var numbers = "1234567890";
    var lowercase = "abcdefghijklmnopqrstuvwxyz";
    var uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    var special = "~`!@#$%^&*()_+{}[];:'><.,/?|";

    var containsNumber = contains(password, numbers);
    var containsLowercase = contains(password, lowercase);
    var containsUppercase = contains(password, uppercase);
    var containsSpecial = contains(password, special);

    var chkStatus = true;

    if (containsNumber == false)
        chkStatus = false;

    if (containsLowercase == false)
        chkStatus = false;

    if (containsUppercase == false)
        chkStatus = false;

    if (containsSpecial == false)
        chkStatus = false;
    
    if (chkStatus == false) {
        document.getElementById(controlId).focus();
        document.getElementById(controlId).className = "skinNormalValidationText";
        document.getElementById(errId).innerHTML = "The password should contain combination of UpperCase, LowerCase, Number and Special Character";
        //alert("Numbers only allowed");
        return "pass";
    }
    else {
        return "";
    }
}

//URL Validation
function URLValidation(controlId, errId) {


    var chkTxt = document.getElementById(controlId).value;

    var atpos = chkTxt.indexOf(".");
    var dotpos = chkTxt.lastIndexOf(".");
    var lenTex = chkTxt.length;
    var diff = lenTex - dotpos;

    if (atpos < 1 || diff <= 3) {
        document.getElementById(controlId).focus();
        document.getElementById(controlId).className = "skinNormalValidationText";
        document.getElementById(errId).innerHTML = "Enter correct URL";
        return "URL";
    }
    else {
        return "";
    }
}

//Email Validation
function emailValidation(controlId, errId) {

    var chkTxt = " ";
    chkTxt = document.getElementById(controlId).value;

    if (!(/^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$/.test(chkTxt))) {
        document.getElementById(controlId).focus();
        document.getElementById(controlId).className = "skinNormalValidationText";
        document.getElementById(errId).innerHTML = "Invalid E-Mail Id";
        return "Email";
        //return message = alertMessage;
    }
    else {
        return "";
        //return message = "";
    }
}

//confirm Validation
function confirmValidation(controlId1, controlId2, errId) {
    controlId1 = controlId1;
    controlId2 = controlId2;

    var chkTxt1 = document.getElementById(controlId1).value;
    var chkTxt2 = document.getElementById(controlId2).value;

    if (chkTxt1 != chkTxt2) {
        
        document.getElementById(controlId1).className = "skinNormalValidationText";
        document.getElementById(controlId2).className = "skinNormalValidationText";
        document.getElementById(controlId1).value = "";
        document.getElementById(controlId2).value = "";
        document.getElementById(controlId1).focus();
        document.getElementById(errId).innerHTML = "Password & Confirm Password must be same";
        return "confirm";
        //return message = alertMessage;
    }
    else {
        return "";
        //return message = "";
    }
}

//Time validation

function timevalidation(controlId, errId) {

    var chktimetxt = document.getElementById(controlId).value;

    var chktimesplit = new Array();
    chktimesplit = chktimetxt.split(':');
    var timeHr = chktimetxt.indexOf(":");
    var ValidChars = "1234567890:";
    var Char;
    var chkStatus = true;

    for (i = 0; i < chktimetxt.length; i++) {
        Char = chktimetxt.charAt(i);
        if (ValidChars.indexOf(Char) == -1) {

            chkStatus = false;
            break;
        }
    }
    if (chkStatus == false) {
        document.getElementById(controlId).focus();
        document.getElementById(controlId).className = "skinNormalValidationText";
        document.getElementById(errId).innerHTML = "Enter Time Format";
        //alert("Numbers only allowed");
        return "Time";
    }

    if (chktimesplit[0] > 12 || chktimesplit[1] > 59) {
        document.getElementById(controlId).focus();
        document.getElementById(errId).innerHTML = "Enter Time (00:00)";
        return "Time";
    }
    else if (timeHr != 2) {
        document.getElementById(controlId).focus();
        document.getElementById(errId).innerHTML = "Enter Correct Time(00:00)";
        return "Time";

    }
    else {
        return "";
    }

}

///Trim a string

function Trim(str) {
    while (str.charAt(0) == (" ")) {
        str = str.substring(1);
    }
    while (str.charAt(str.length - 1) == " ") {
        str = str.substring(0, str.length - 1);
    }
    return str;
}



///ClearErrMsg

function ClearErrMsg(divId, controlId) {
    
    document.getElementById(divId).className = "divErrorHide";
    document.getElementById(controlId).className = "skinNormalText";
}

///ClearErrMsg

function GoToNxtTxtBox(event, ctrlId) {

  if(event.keyCode != null)
  { 
    if(event.keyCode==13)
        document.getElementById(ctrlId).focus();
  }
  else
  {
    if(event.which==13)
        document.getElementById(ctrlId).focus(); 
  } 
  
//    if (event.keyCode==13) 
//    {
//    alert('1');
//        event.keyCode=9; 
//        alert('2');
//        return event.keyCode 
//        alert('3');
//        
//    }
    //document.getElementById(txtBoxId).focus();
}

///ModalFocus

function ModalFocus(txtBoxId) {
    setTimeout("document.getElementById('" + txtBoxId + "').focus()",100);
}


