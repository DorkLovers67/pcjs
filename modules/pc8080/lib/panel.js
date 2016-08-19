/**
 * @fileoverview Implements the PC8080 Panel component.
 * @author <a href="mailto:Jeff@pcjs.org">Jeff Parsons</a>
 * @version 1.0
 * Created 2016-Apr-19
 *
 * Copyright © 2012-2016 Jeff Parsons <Jeff@pcjs.org>
 *
 * This file is part of PCjs, a computer emulation software project at <http://pcjs.org/>.
 *
 * PCjs is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3
 * of the License, or (at your option) any later version.
 *
 * PCjs is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
 * even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with PCjs.  If not,
 * see <http://www.gnu.org/licenses/gpl.html>.
 *
 * You are required to include the above copyright notice in every source code file of every
 * copy or modified version of this work, and to display that copyright notice on every screen
 * that loads or runs any version of this software (see COPYRIGHT in /modules/shared/lib/defines.js).
 *
 * Some PCjs files also attempt to load external resource files, such as character-image files,
 * ROM files, and disk image files. Those external resource files are not considered part of PCjs
 * for purposes of the GNU General Public License, and the author does not claim any copyright
 * as to their contents.
 */

"use strict";

if (NODE) {
    var str         = require("../../shared/lib/strlib");
    var usr         = require("../../shared/lib/usrlib");
    var web         = require("../../shared/lib/weblib");
    var Component   = require("../../shared/lib/component");
    var Bus8080     = require("./bus");
    var CPUDef8080  = require("./cpudef");
    var Memory8080  = require("./memory");
}

/**
 * Panel8080(parmsPanel)
 *
 * The Panel8080 component has no required (parmsPanel) properties.
 *
 * @constructor
 * @extends Component
 * @param {Object} parmsPanel
 */
function Panel8080(parmsPanel)
{
    Component.call(this, "Panel", parmsPanel, Panel8080);
}

Component.subclass(Panel8080);

/**
 * setBinding(sHTMLType, sBinding, control, sValue)
 *
 * Most panel layouts don't have bindings of their own, so we pass along all binding requests to the
 * Computer, CPU, Keyboard and Debugger components first.  The order shouldn't matter, since any component
 * that doesn't recognize the specified binding should simply ignore it.
 *
 * @this {Panel8080}
 * @param {string|null} sHTMLType is the type of the HTML control (eg, "button", "list", "text", "submit", "textarea", "canvas")
 * @param {string} sBinding is the value of the 'binding' parameter stored in the HTML control's "data-value" attribute (eg, "reset")
 * @param {Object} control is the HTML control DOM object (eg, HTMLButtonElement)
 * @param {string} [sValue] optional data value
 * @return {boolean} true if binding was successful, false if unrecognized binding request
 */
Panel8080.prototype.setBinding = function(sHTMLType, sBinding, control, sValue)
{
    if (this.cmp && this.cmp.setBinding(sHTMLType, sBinding, control, sValue)) return true;
    if (this.cpu && this.cpu.setBinding(sHTMLType, sBinding, control, sValue)) return true;
    if (this.kbd && this.kbd.setBinding(sHTMLType, sBinding, control, sValue)) return true;
    if (DEBUGGER && this.dbg && this.dbg.setBinding(sHTMLType, sBinding, control, sValue)) return true;
    return this.parent.setBinding.call(this, sHTMLType, sBinding, control, sValue);
};

/**
 * initBus(cmp, bus, cpu, dbg)
 *
 * @this {Panel8080}
 * @param {Computer8080} cmp
 * @param {Bus8080} bus
 * @param {CPUState8080} cpu
 * @param {Debugger8080} dbg
 */
Panel8080.prototype.initBus = function(cmp, bus, cpu, dbg)
{
    this.cmp = cmp;
    this.bus = bus;
    this.cpu = cpu;
    this.dbg = dbg;
    this.kbd = /** @type {Keyboard8080} */ (cmp.getMachineComponent("Keyboard"));
};

/**
 * powerUp(data, fRepower)
 *
 * @this {Panel8080}
 * @param {Object|null} data
 * @param {boolean} [fRepower]
 * @return {boolean} true if successful, false if failure
 */
Panel8080.prototype.powerUp = function(data, fRepower)
{
    if (!fRepower) Panel8080.init();
    return true;
};

/**
 * powerDown(fSave, fShutdown)
 *
 * @this {Panel8080}
 * @param {boolean} [fSave]
 * @param {boolean} [fShutdown]
 * @return {Object|boolean} component state if fSave; otherwise, true if successful, false if failure
 */
Panel8080.prototype.powerDown = function(fSave, fShutdown)
{
    return true;
};

/**
 * updateStatus(fForce)
 *
 * Update function for Panels containing elements with high-frequency display requirements.
 *
 * For older (and slower) DOM-based display elements, those are sill being managed by the CPUState component,
 * so it has its own updateStatus() handler.
 *
 * The Computer's updateStatus() handler is currently responsible for calling both our handler and the CPU's handler.
 *
 * @this {Panel8080}
 * @param {boolean} [fForce] (true will display registers even if the CPU is running and "live" registers are not enabled)
 */
Panel8080.prototype.updateStatus = function(fForce)
{
};

/**
 * Panel8080.init()
 *
 * This function operates on every HTML element of class "panel", extracting the
 * JSON-encoded parameters for the Panel8080 constructor from the element's "data-value"
 * attribute, invoking the constructor to create a Panel8080 component, and then binding
 * any associated HTML controls to the new component.
 *
 * NOTE: Unlike most other component init() functions, this one is designed to be
 * called multiple times: once at load time, so that we can bind our print()
 * function to the panel's output control ASAP, and again when the Computer component
 * is verifying that all components are ready and invoking their powerUp() functions.
 *
 * Our powerUp() method gives us a second opportunity to notify any components that
 * that might care (eg, CPU, Keyboard, and Debugger) that we have some controls they
 * might want to use.
 */
Panel8080.init = function()
{
    var fReady = false;
    var aePanels = Component.getElementsByClass(document, PC8080.APPCLASS, "panel");
    for (var iPanel=0; iPanel < aePanels.length; iPanel++) {
        var ePanel = aePanels[iPanel];
        var parmsPanel = Component.getComponentParms(ePanel);
        var panel = Component.getComponentByID(parmsPanel['id']);
        if (!panel) {
            fReady = true;
            panel = new Panel8080(parmsPanel);
        }
        Component.bindComponentControls(panel, ePanel, PC8080.APPCLASS);
        if (fReady) panel.setReady();
    }
};

/*
 * Initialize every Panel module on the page.
 */
web.onInit(Panel8080.init);

if (NODE) module.exports = Panel8080;
