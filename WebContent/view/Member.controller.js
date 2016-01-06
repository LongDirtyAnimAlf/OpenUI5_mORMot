sap.ui.define([
	'sap/ui/demo/mORMot/localService/BaseController',
	'sap/ui/demo/mORMot/model/formatter',
	'sap/m/MessageToast',
	'sap/m/MessageBox'
], function (BaseController, formatter, MessageToast, MessageBox) {
	return BaseController.extend("sap.ui.demo.mORMot.view.Member", {
		formatter : formatter,

		onInit : function () {
			this._router().getRoute("Member").attachPatternMatched(this._routePatternMatched, this);
			this._router().getRoute("TeamMember").attachPatternMatched(this._routePatternMatched, this);
		},

		_routePatternMatched: function(oEvent) {
			var sId = oEvent.getParameter("arguments").MemberID;
			var	oView = this.getView();
			var oModel = oView.getModel();
			var sPath = "/Member/"+sId;
			var sKey = sPath.substr(1);
			var oData = oModel.getData(sPath);
			
			//oView.objectBindings({			
			oView.bindElement({
				path: sPath,
				events: {
					dataRequested: function () {
						oView.setBusy(true);
					},
					dataReceived: function () {
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
		
		onShowResume : function (oEvent) {
			var oData = this.getView().getBindingContext().getProperty();
			if (oData) {
				this._router().navTo("MemberResume", {
					TeamID : oData.MemberTeam, MemberID : oData.ID				
				});
			}
		},
		
		_checkIfMemberAvailable: function(sPath, sId) {
			var oModel = this.getView().getModel();
			// remove starting slash
			var sKey = sPath.substr(1);
			var oData = oModel.oData[sKey];
			if (!oData) {
				// show not found page				
				this._router().getTargets().display("notFound", sId);
			}
		},

		handleMemberCallButtonPress: function() {
			var oData = this.getView().getBindingContext().getProperty();
			sap.m.URLHelper.triggerTel(oData.Phone);
		},

		handleMemberTextButtonPress: function() {
			var oData = this.getView().getBindingContext().getProperty();
			sap.m.URLHelper.triggerSms(oData.Phone);
		},

		handleMemberMailButtonPress: function() {
			var oData = this.getView().getBindingContext().getProperty();
			sap.m.URLHelper.triggerEmail(oData.Email);
		}
	});
});
