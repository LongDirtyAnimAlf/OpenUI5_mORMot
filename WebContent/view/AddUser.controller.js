sap.ui.define([
	'sap/ui/demo/mORMot/localService/BaseController',
	'sap/m/MessageToast',
	'sap/m/MessageBox'	
], function (BaseController, formatter, MessageToast, MessageBox) {
	return BaseController.extend("sap.ui.demo.mORMot.view.AddUser", {
 
		onInit: function() {
			this.getView().setModel(new sap.ui.model.json.JSONModel(), "newUser");
			this._router().getRoute("AddUser").attachPatternMatched(this._routePatternMatched, this);
		},

		_routePatternMatched: function(oEvent) {
			var sId = oEvent.getParameter("arguments").TeamID;
			var oSelect = this.getView().byId("idSelectTeam");
			oSelect.setSelectedKey(sId);			
		},
		
		onCancel: function() {
			sap.ui.core.UIComponent.getRouterFor(this).backWithoutHash(this.getView());
		},

		onSave: function() {
			var mData = this.getView().getModel("newUser").getData();
			var oSelect = this.getView().byId("idSelectTeam");
			var oItem = oSelect.getSelectedItem();
			var iTeam = parseInt(oItem.getKey());	
			var mNewUser = {
					"Email": mData.Email,
					"FirstName": mData.FirstName,
					"LastName": mData.LastName,
					"Phone": mData.Phone,
					"MemberTeam": iTeam      
			};
    
			var oModel = this.getView().getModel();
			oModel.create("/Member", mNewUser, {
				success: jQuery.proxy(function(mResponse) {
					sap.m.MessageToast.show("Hello " + mNewUser.FirstName + " " + mNewUser.LastName)
				}, this),
				error: jQuery.proxy(function() {
					alert("Problem creating new user");
				}, this)
			});
		}
	});
});
