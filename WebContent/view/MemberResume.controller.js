sap.ui.define([
	'sap/ui/demo/mORMot/localService/BaseController',
	'sap/ui/demo/mORMot/model/formatter'
], function (BaseController, formatter) {
	
	return BaseController.extend("sap.ui.demo.mORMot.view.MemberResume", {
		onInit: function () {
			this._router().getRoute("MemberResume").attachMatched(this._onRouteMatched, this);			
		},
		_onRouteMatched : function (oEvent) {
			var oView = this.getView();
			var oModel = oView.getModel();
			var sId = Number(oEvent.getParameter("arguments").MemberID);			
			var sPath = "/Member/" + sId;
			var oData = oModel.getData(sPath);
			
			oView.bindElement({
				path : sPath,
				events : {
					dataRequested: function (oEvent) {
						oView.setBusy(true);
					},
					dataReceived: function (oEvent) {
						oView.setBusy(false);
					}
				}
			});
			
			//if there is no data the model has to request new data
			if (!oData) {
				oView.setBusyIndicatorDelay(0);
				oView.getElementBinding().attachEventOnce("dataReceived", function() {
					// reset to default
					oView.setBusyIndicatorDelay(null);
					this._checkIfMemberAvailable(sPath, sId);
				}.bind(this));
			}
		},
		_onBindingChange : function (oEvent) {
			// No data for the binding
			if (!this.getView().getBindingContext()) {
				this._router().getTargets().display("notFound");
			}
		},
		_checkIfMemberAvailable: function(sPath, sId) {
			var oModel = this.getView().getModel();
			var oData = oModel.getProperty(sPath);			

			// show not found page
			if (!oData) {
				this._router().getTargets().display("notFound", sId);
			}
		}
		
	});
});
