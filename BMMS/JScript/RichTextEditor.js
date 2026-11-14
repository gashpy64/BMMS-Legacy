// Step A2a: the rich-text editor (BMMS.Controls.RichTextEditor, in place of FreeTextBox). Chrome and Edge.
//
// Each editor is a div.rte[data-rte] with a toolbar, a contenteditable div.rte-box, a hidden input that is
// the only posted field, and a message line. The server renders the cleaned text into the box and the same
// text, as Base64 of its UTF-8 bytes, into the hidden input. This script replaces the hidden value only after
// a real edit (typing, paste, drop or a toolbar action): an untouched box is never serialised again, so an
// untouched Update posts back exactly what the server rendered.
//
// Paste keeps the allow-list of the server's HtmlCleaner (p, br, b, strong, i, em, u, ul, ol, li, table and its
// parts, align, colspan, rowspan) and turns Word's list paragraphs into real lists where it can; the server
// cleans every posted value again, so this is a convenience, not the check.
//
// Limits (RichTextLimits on the server, written into data-rte-max and data-rte-max-total): the length of the
// box's HTML is counted after each edit; over a limit the message shows under the editor, and a post started
// by a button (full or partial) is cancelled. A post started by a drop-down still goes; the server refuses
// to save and keeps the text.
//
// Sys.Application "load" runs again after every partial postback: new editors are set up then; editors of a
// replaced panel go away with their elements. Document listeners are added once.

(function () {
    "use strict";

    // The wording comes from the server (RichTextLimits.TooLongMessage, in data-rte-too-long)
    var TooLongMessageFallback = "The text is too long. Shorten it or attach the document as a file.";

    var Allowed = { p: 1, br: 1, b: 1, strong: 1, i: 1, em: 1, u: 1, ul: 1, ol: 1, li: 1,
        table: 1, thead: 1, tbody: 1, tr: 1, th: 1, td: 1 };

    var RemovedWithContent = { script: 1, style: 1, iframe: 1, frame: 1, frameset: 1, object: 1, embed: 1,
        applet: 1, param: 1, noscript: 1, template: 1, svg: 1, math: 1, head: 1, title: 1, meta: 1, link: 1,
        base: 1, xml: 1, input: 1, select: 1, option: 1, optgroup: 1, textarea: 1, button: 1, img: 1,
        picture: 1, source: 1, audio: 1, video: 1, track: 1, canvas: 1, map: 1, area: 1, caption: 1, col: 1,
        colgroup: 1 };

    var Toggles = ["bold", "italic", "underline", "insertUnorderedList", "insertOrderedList",
        "justifyLeft", "justifyCenter", "justifyRight", "justifyFull"];

    var MaxDepth = 200;

    // ---------------------------------------------------------------- set-up

    function init() {
        var roots = document.querySelectorAll("div.rte[data-rte]");
        for (var i = 0; i < roots.length; i++) {
            if (!roots[i].getAttribute("data-rte-ready"))
                setUp(roots[i]);
        }
        addDocumentListeners();
    }

    function setUp(root) {
        var box = root.querySelector(".rte-box");
        var input = root.querySelector("input[type=hidden]");
        if (!box || !input)
            return;

        root.setAttribute("data-rte-ready", "1");

        var state = {
            root: root,
            box: box,
            input: input,
            message: root.querySelector(".rte-message"),
            toolbar: root.querySelector(".rte-toolbar"),
            dirty: false,
            length: parseInt(box.getAttribute("data-rte-len"), 10) || 0,
            max: positive(root.getAttribute("data-rte-max"), 200000),
            maxTotal: positive(root.getAttribute("data-rte-max-total"), 600000),
            tooLongMessage: root.getAttribute("data-rte-too-long") || TooLongMessageFallback,
            timer: 0
        };
        root.rteState = state;

        box.addEventListener("input", function () { markDirty(state); });
        box.addEventListener("paste", function (e) { onPaste(e, state); });
        box.addEventListener("drop", function (e) { onDrop(e, state); });
        box.addEventListener("keydown", function (e) { onKeyDown(e, state); });
        box.addEventListener("blur", function () { sync(state); });
        box.addEventListener("focus", function () { updateToolbar(state); });

        if (state.toolbar) {
            var buttons = state.toolbar.querySelectorAll("button[data-rte-cmd]");
            if (buttons.length > 0)
                buttons[0].setAttribute("tabindex", "0");

            // Keep the selection in the box when a button is pressed with the mouse
            state.toolbar.addEventListener("mousedown", function (e) {
                if (closestButton(e.target))
                    e.preventDefault();
            });
            state.toolbar.addEventListener("click", function (e) {
                var button = closestButton(e.target);
                if (button)
                    runCommand(state, button.getAttribute("data-rte-cmd"));
            });
            state.toolbar.addEventListener("keydown", function (e) { onToolbarKey(e, state); });
        }
    }

    var documentListenersAdded = false;

    function addDocumentListeners() {
        if (documentListenersAdded)
            return;
        documentListenersAdded = true;

        // Capture phase: runs before the PageRequestManager's own submit handler on the form
        document.addEventListener("submit", onSubmit, true);

        document.addEventListener("selectionchange", function () {
            var state = stateOf(document.activeElement);
            if (state)
                updateToolbar(state);
        });

        if (typeof (Sys) != "undefined" && Sys.WebForms && Sys.WebForms.PageRequestManager) {
            var prm = Sys.WebForms.PageRequestManager.getInstance();
            if (prm)
                prm.add_initializeRequest(onInitializeRequest);
        }
    }

    // ---------------------------------------------------------------- editing

    function markDirty(state) {
        state.dirty = true;
        if (state.timer)
            window.clearTimeout(state.timer);
        state.timer = window.setTimeout(function () {
            state.timer = 0;
            measure(state);
            showLimits();
        }, 300);
    }

    function runCommand(state, command) {
        state.box.focus();
        prepareCommands();
        document.execCommand(command, false, null);
        markDirty(state);
        updateToolbar(state);
    }

    function prepareCommands() {
        // <b> and <i> rather than styled spans; Enter starts a new <p>
        try { document.execCommand("styleWithCSS", false, false); } catch (ignore) { }
        try { document.execCommand("defaultParagraphSeparator", false, "p"); } catch (ignore) { }
    }

    function onKeyDown(e, state) {
        if (e.key === "Tab" && !e.ctrlKey && !e.altKey && !e.metaKey && selectionInList(state.box)) {
            // Tab and Shift+Tab nest a list item or move it back out; elsewhere Tab moves the focus as usual
            e.preventDefault();
            runCommand(state, e.shiftKey ? "outdent" : "indent");
        }
    }

    function selectionInList(box) {
        var selection = window.getSelection();
        if (!selection || selection.rangeCount === 0)
            return false;
        var node = selection.getRangeAt(0).startContainer;
        while (node && node !== box) {
            if (node.nodeType === 1 && node.nodeName.toLowerCase() === "li")
                return true;
            node = node.parentNode;
        }
        return false;
    }

    function onPaste(e, state) {
        var data = e.clipboardData;
        if (!data)
            return;
        e.preventDefault();
        insertTransfer(state, data);
    }

    function onDrop(e, state) {
        var data = e.dataTransfer;
        e.preventDefault();
        if (!data)
            return;
        // The text goes where the mouse was let go
        if (document.caretRangeFromPoint) {
            var range = document.caretRangeFromPoint(e.clientX, e.clientY);
            if (range) {
                var selection = window.getSelection();
                selection.removeAllRanges();
                selection.addRange(range);
            }
        }
        insertTransfer(state, data);
    }

    function insertTransfer(state, data) {
        var html = data.getData("text/html");
        var text = data.getData("text/plain");

        state.box.focus();
        prepareCommands();

        // execCommand keeps the insert in the browser's undo history
        if (html)
            document.execCommand("insertHTML", false, sanitize(html));
        else if (text)
            document.execCommand("insertText", false, text);
        else
            return;     // files and pictures are not taken

        markDirty(state);
    }

    // ---------------------------------------------------------------- toolbar

    function closestButton(node) {
        while (node && node.nodeType === 1) {
            if (node.nodeName.toLowerCase() === "button" && node.hasAttribute("data-rte-cmd"))
                return node;
            if (node.classList && node.classList.contains("rte-toolbar"))
                return null;
            node = node.parentNode;
        }
        return null;
    }

    function updateToolbar(state) {
        if (!state.toolbar)
            return;
        for (var i = 0; i < Toggles.length; i++) {
            var button = state.toolbar.querySelector("button[data-rte-cmd=" + Toggles[i] + "]");
            if (!button)
                continue;
            var on = false;
            try { on = document.queryCommandState(Toggles[i]); } catch (ignore) { }
            button.setAttribute("aria-pressed", on ? "true" : "false");
        }
    }

    // Arrow keys, Home and End move between the buttons; Tab leaves the toolbar
    function onToolbarKey(e, state) {
        var buttons = Array.prototype.slice.call(state.toolbar.querySelectorAll("button[data-rte-cmd]"));
        var index = buttons.indexOf(document.activeElement);
        if (index < 0)
            return;
        var next = -1;
        if (e.key === "ArrowRight") next = (index + 1) % buttons.length;
        else if (e.key === "ArrowLeft") next = (index - 1 + buttons.length) % buttons.length;
        else if (e.key === "Home") next = 0;
        else if (e.key === "End") next = buttons.length - 1;
        if (next < 0)
            return;
        e.preventDefault();
        buttons[index].setAttribute("tabindex", "-1");
        buttons[next].setAttribute("tabindex", "0");
        buttons[next].focus();
    }

    // ---------------------------------------------------------------- value and limits

    // Writes the hidden value from the box, only after an edit. Empty text when the box shows nothing.
    function sync(state) {
        if (!state.dirty)
            return;
        measure(state);
        state.input.value = state.length === 0 ? "" : toBase64(state.box.innerHTML);
    }

    function measure(state) {
        state.length = isBlankBox(state.box) ? 0 : state.box.innerHTML.length;
    }

    function isBlankBox(box) {
        return box.textContent.replace(/[\s ​]/g, "").length === 0;
    }

    function allStates() {
        var result = [];
        var roots = document.querySelectorAll("div.rte[data-rte-ready]");
        for (var i = 0; i < roots.length; i++) {
            if (roots[i].rteState)
                result.push(roots[i].rteState);
        }
        return result;
    }

    // Shows or hides the message of each editor; true when every editor and the page total are within limits
    function showLimits() {
        var states = allStates();
        var total = 0;
        var maxTotal = 0;
        var ok = true;
        var lastOver = null;

        for (var i = 0; i < states.length; i++) {
            total += states[i].length;
            maxTotal = states[i].maxTotal;
        }
        var totalOver = states.length > 0 && total > maxTotal;

        for (var j = 0; j < states.length; j++) {
            var over = states[j].length > states[j].max;
            // Over the page total: the message goes under the editors that were changed
            var show = over || (totalOver && states[j].dirty);
            setMessage(states[j], show);
            if (show) {
                ok = false;
                lastOver = states[j];
            }
        }
        if (totalOver && !lastOver && states.length > 0) {
            setMessage(states[0], true);
            lastOver = states[0];
        }
        return { ok: ok && !totalOver, first: lastOver };
    }

    function setMessage(state, show) {
        if (!state.message)
            return;
        var text = show ? state.tooLongMessage : "";
        if (state.message.textContent !== text)
            state.message.textContent = text;
        state.root.classList.toggle("rte-over", show);
    }

    // Before any post started by a button: write every changed editor, then stop the post when over a limit
    function checkBeforePost() {
        var states = allStates();
        for (var i = 0; i < states.length; i++)
            sync(states[i]);
        var limits = showLimits();
        if (!limits.ok) {
            // The page's own "please wait" layer (Agenda Entry) must not stay on
            var progress = document.getElementById("divProgress");
            if (progress)
                progress.style.visibility = "hidden";
            if (limits.first)
                limits.first.box.focus();
        }
        return limits.ok;
    }

    function onSubmit(e) {
        if (!checkBeforePost()) {
            e.preventDefault();
            e.stopPropagation();
        }
    }

    function onInitializeRequest(sender, args) {
        if (!checkBeforePost())
            args.set_cancel(true);
    }

    function toBase64(text) {
        var bytes = new TextEncoder().encode(text);
        var binary = "";
        for (var i = 0; i < bytes.length; i += 0x8000)
            binary += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
        return window.btoa(binary);
    }

    function positive(value, fallback) {
        var n = parseInt(value, 10);
        return n > 0 ? n : fallback;
    }

    function stateOf(node) {
        while (node && node.nodeType === 1) {
            if (node.rteState)
                return node.rteState;
            node = node.parentNode;
        }
        return null;
    }

    // ---------------------------------------------------------------- paste clean-up

    // The pasted HTML reduced to the allow-list. DOMParser gives an inert document: nothing in it runs.
    function sanitize(html) {
        var source = new DOMParser().parseFromString(html, "text/html");
        convertWordLists(source);
        var target = document.createElement("div");
        copyChildren(source.body, target, 0);
        return target.innerHTML;
    }

    function copyChildren(from, to, depth) {
        for (var node = from.firstChild; node; node = node.nextSibling)
            copyNode(node, to, depth);
    }

    function copyNode(node, to, depth) {
        if (node.nodeType === 3) {
            to.appendChild(document.createTextNode(node.nodeValue));
            return;
        }
        if (node.nodeType !== 1)
            return;     // comments, including Word's <!--[if ...]>

        var name = node.nodeName.toLowerCase();
        if (RemovedWithContent[name] || isWordListMarker(node))
            return;
        if (depth >= MaxDepth) {
            copyChildren(node, to, depth + 1);
            return;
        }

        var tag = name;
        var boldParagraph = false;
        if (name === "div")
            tag = "p";
        else if (/^h[1-6]$/.test(name)) {
            tag = "p";
            boldParagraph = true;
        }
        else if (name === "tfoot")
            tag = "tbody";

        if (!Allowed[tag]) {
            // Word and Google Docs mark bold, italic and underline with styled spans
            copyStyledInline(node, to, depth);
            return;
        }

        var element = document.createElement(tag);
        if (tag === "table") {
            element.setAttribute("border", "1");
            element.setAttribute("cellpadding", "4");
            element.setAttribute("cellspacing", "0");
        }
        if (tag === "p" || tag === "td" || tag === "th") {
            var align = alignOf(node);
            if (align)
                element.setAttribute("align", align);
        }
        if (tag === "td" || tag === "th") {
            copySpan(node, element, "colspan");
            copySpan(node, element, "rowspan");
        }

        var inner = element;
        if (boldParagraph) {
            inner = document.createElement("strong");
            element.appendChild(inner);
        }
        copyChildren(node, inner, depth + 1);
        to.appendChild(element);
    }

    function copyStyledInline(node, to, depth) {
        var style = (node.getAttribute("style") || "").toLowerCase();
        var target = to;
        var wrappers = [];
        if (/font-weight\s*:\s*(bold|[6-9]00)/.test(style)) wrappers.push("b");
        if (/font-style\s*:\s*italic/.test(style)) wrappers.push("i");
        if (/text-decoration[^;]*underline/.test(style)) wrappers.push("u");
        for (var i = 0; i < wrappers.length; i++) {
            var wrapper = document.createElement(wrappers[i]);
            target.appendChild(wrapper);
            target = wrapper;
        }
        copyChildren(node, target, depth + 1);
    }

    function alignOf(node) {
        var value = node.getAttribute("align");
        if (!value) {
            var match = /text-align\s*:\s*([a-zA-Z]+)/.exec(node.getAttribute("style") || "");
            value = match ? match[1] : "";
        }
        value = value.toLowerCase();
        return value === "left" || value === "right" || value === "center" || value === "justify" ? value : null;
    }

    function copySpan(from, to, attribute) {
        var value = (from.getAttribute(attribute) || "").trim();
        if (/^[0-9]{1,3}$/.test(value)) {
            var n = parseInt(value, 10);
            if (n >= 1 && n <= 100)
                to.setAttribute(attribute, String(n));
        }
    }

    // ---------------------------------------------------------------- Word lists

    // Word puts the bullet or number of a list paragraph in <span style="mso-list:Ignore">
    function isWordListMarker(node) {
        return /mso-list\s*:\s*ignore/i.test(node.getAttribute("style") || "");
    }

    function isWordListParagraph(node) {
        if (node.nodeType !== 1)
            return false;
        var style = node.getAttribute("style") || "";
        return /MsoListParagraph/i.test(node.getAttribute("class") || "")
            || (/mso-list\s*:/i.test(style) && !/mso-list\s*:\s*ignore/i.test(style));
    }

    function wordListLevel(node) {
        var match = /level(\d+)/i.exec(node.getAttribute("style") || "");
        return match ? parseInt(match[1], 10) : 1;
    }

    function wordListIsNumbered(node) {
        var markers = node.querySelectorAll("span");
        for (var i = 0; i < markers.length; i++) {
            if (isWordListMarker(markers[i]))
                return /^\s*\(?([0-9]+|[a-zA-Z]|[ivxlcdmIVXLCDM]+)[.)]/.test(markers[i].textContent);
        }
        return false;
    }

    // Each run of Word list paragraphs (siblings, white space between them allowed) becomes nested ul/ol
    function convertWordLists(doc) {
        var candidates = Array.prototype.slice.call(doc.body.querySelectorAll("p, div, h1, h2, h3, h4, h5, h6"));
        var done = [];

        for (var i = 0; i < candidates.length; i++) {
            var first = candidates[i];
            if (done.indexOf(first) >= 0 || !isWordListParagraph(first) || !first.parentNode)
                continue;

            var run = [first];
            var node = first.nextSibling;
            while (node) {
                if (node.nodeType === 3 && !node.nodeValue.trim()) {
                    node = node.nextSibling;
                    continue;
                }
                if (node.nodeType === 8) {      // comments between the paragraphs
                    node = node.nextSibling;
                    continue;
                }
                if (!isWordListParagraph(node))
                    break;
                run.push(node);
                node = node.nextSibling;
            }

            var stack = [];
            var top = null;
            for (var j = 0; j < run.length; j++) {
                var item = run[j];
                var level = wordListLevel(item);
                while (stack.length > 0 && stack[stack.length - 1].level > level)
                    stack.pop();
                top = stack.length > 0 ? stack[stack.length - 1] : null;
                if (!top || top.level < level) {
                    var list = doc.createElement(wordListIsNumbered(item) ? "ol" : "ul");
                    if (!top)
                        first.parentNode.insertBefore(list, first);
                    else
                        (top.list.lastElementChild || top.list).appendChild(list);
                    top = { level: level, list: list };
                    stack.push(top);
                }
                var li = doc.createElement("li");
                while (item.firstChild)
                    li.appendChild(item.firstChild);
                top.list.appendChild(li);
                item.parentNode.removeChild(item);
                done.push(item);
            }
        }
    }

    // ---------------------------------------------------------------- start

    if (typeof (Sys) != "undefined" && Sys.Application)
        Sys.Application.add_load(init);
    else if (document.readyState === "loading")
        document.addEventListener("DOMContentLoaded", init);
    else
        init();
})();

if (typeof (Sys) != "undefined")
    Sys.Application.notifyScriptLoaded();
