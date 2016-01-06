sap.ui.define([
	"sap/ui/core/mvc/Controller",
	"sap/ui/core/routing/History"
], function (Controller, History) {
	"use strict";

	return Controller.extend("sap.ui.demo.mORMot.BaseController", {

		_router : function () {
			return sap.ui.core.UIComponent.getRouterFor(this);
		},
		
		_eventBus : function () { 
			return this.getOwnerComponent().getEventBus(); 
		}, 

		handleNavButtonPress: function (oEvent) {
			var oHistory, sPreviousHash;

			oHistory = History.getInstance();
			sPreviousHash = oHistory.getPreviousHash();

			if (sPreviousHash !== undefined) {
				window.history.go(-1);
			} else {
				this._router().navTo("home", {}, true /*no history*/);
			}
		}

	});

});
