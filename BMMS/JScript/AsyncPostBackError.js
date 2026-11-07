// Step E1: a failed UpdatePanel postback is shown in the message bar of the page (div#wbAsyncError in
// Main.Master, MainNoMenu.Master and Default.aspx) instead of only in the browser console. The server has
// already written the error to the error log (Utilities.LogAsyncPostBackError) and sends only a fixed text,
// so no exception text reaches the browser. Never uses alert or confirm.
//
// A page's own endRequest handler added in Sys.Application.add_init (Reset Database) runs before this one;
// when it calls args.set_errorHandled(true), this one does nothing. A page that adds its own handler later
// must check args.get_errorHandled() itself.

(function () {
    var ServerErrorText = "This action could not be completed because of an error on the server. The error is in the error log. Reload the page and check what was saved before you try again.";
    var TimeoutText = "The server did not answer in time. Reload the page and check what was saved before you try again.";

    function showMessage(text) {
        var bar = document.getElementById("wbAsyncError");
        if (!bar)
            return;
        // The text replaces whatever the bar showed before: one message, never two
        while (bar.firstChild)
            bar.removeChild(bar.firstChild);
        bar.appendChild(document.createTextNode(text));
        bar.style.display = "block";
    }

    function hideMessage() {
        var bar = document.getElementById("wbAsyncError");
        if (bar)
            bar.style.display = "none";
    }

    function onBeginRequest(sender, args) {
        hideMessage();
    }

    function onEndRequest(sender, args) {
        var error = args.get_error();
        if (error == null || args.get_errorHandled())
            return;

        args.set_errorHandled(true);
        showMessage(error.name == "Sys.WebForms.PageRequestManagerTimeoutException" ? TimeoutText : ServerErrorText);

        // The error name only, for whoever looks at the console; the message stays on the server
        if (window.console && window.console.error)
            window.console.error("Partial postback failed: " + error.name);
    }

    if (typeof (Sys) == "undefined")
        return;

    // Sys.Application "load" fires again after every partial postback: register the handlers once per page
    Sys.Application.add_load(function () {
        if (window.bmmsAsyncErrorHandlersAdded)
            return;
        window.bmmsAsyncErrorHandlersAdded = true;

        var prm = Sys.WebForms.PageRequestManager.getInstance();
        prm.add_beginRequest(onBeginRequest);
        prm.add_endRequest(onEndRequest);
    });
})();

if (typeof (Sys) != "undefined")
    Sys.Application.notifyScriptLoaded();
