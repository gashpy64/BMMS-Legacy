
// Lock Back Space in all browser

window.history.go(1);

// Lock Right click in all browser
//document.oncontextmenu = function(){return false;};

// Lock text selection all text boxes, etc., in all browser
//document.onselectstart= function() {return false;}; 
function popupDialogHide(width,height,pageName, pageTitle)
{
    var sFeatures = "dialogHide:on; dialogHeight: 100px; dialogWidth: 100px";
    window.showModalDialog(pageName, 'pageTitle', sFeatures)
}

function popupDialog(width,height,pageName, pageTitle)
{
    var TopPosition = 0;
    var LeftPosition = 0;
    
    if(window.innerWidth)
    {
	    LeftPosition =(window.innerWidth-width)/2;
	    TopPosition =((window.innerHeight-height)/4)-50;
    }
	else
	{
	    LeftPosition =(parseInt(window.screen.width)-	width)/2;
	    TopPosition=((parseInt(window.screen.height)-height)/2)-50;
    }
			
    var sFeatures = "dialogTop: " + TopPosition + "px; dialogLeft: " + LeftPosition + "px; center: yes; resizable: no; status: no; dialogHeight: " + height + "px; dialogWidth:" + width + "px;";
    window.showModalDialog(pageName, 'pageTitle', sFeatures)

}

function popup(width,height,pageName, pageTitle){
	if(window.innerWidth){
	LeftPosition =(window.innerWidth-width)/2;
	TopPosition =((window.innerHeight-height)/4)-50;
			}
	else{
	LeftPosition =(parseInt(window.screen.width)-	width)/2;
	TopPosition=((parseInt(window.screen.height)-height)/2)-50;
			}
	attr = 'resizable=no,scrollbars=yes,width=' + width + ',height=' +
	height + ',screenX=300,screenY=200,left=' + LeftPosition + ',top=' +
	TopPosition + '';
	popWin=open(pageName, 'pageTitle', attr);

//	popWin.document.write('<head><title>Test Popup</title></head>');
//	popWin.document.write('<body><div align=center>');
//	popWin.document.write('<b>This is a test popup window</b><br><br>');
//  	popWin.document.write('Content goes here<br>');
//	popWin.document.write('Content goes here<br>');
//	popWin.document.write('Content goes here<br>');
//  	popWin.document.write('</div></body></html>');
}