sap.ui.define([
	'sap/ui/demo/mORMot/localService/BaseController',
	'sap/ui/demo/mORMot/model/formatter',
	'sap/ui/Device',
	'sap/ui/model/Filter',
	'sap/ui/model/FilterOperator',
	'sap/m/Dialog',
	'sap/m/Button'
], function (BaseController,
			 formatter,
			 Device,
			 Filter,
			 FilterOperator,
			 Dialog,
			 Button) {
	"use strict";

	
	return BaseController.extend("sap.ui.demo.mORMot.view.Team", {
		formatter : formatter,

		_sId:0,		
		
		onInit : function () {
			this._router().getRoute("Team").attachMatched(this._loadTeam, this);
		},
		
		_loadTeam : function(oEvent) {
			this._sId = oEvent.getParameter("arguments").TeamID;			
			//this._sId = oEvent.getParameters().arguments.TeamID;
			var	oView = this.getView();
			var sPath = "/Team/"+this._sId;
			var oData = oView.getModel().getData(sPath);
			
			if (oData) {
				oView.byId("page").setTitle(oData.Name);
			} else {
				oView.byId("page").setTitle(this._sId);
			}
			
			
			var oMemberList = this.getView().byId("MemberList");
			this._changeNoDataTextToIndicateLoading(oMemberList);
			var oBinding = oMemberList.getBinding("items");
			oBinding.attachDataReceived(this.fnDataReceived, this);

			// not available !!
			this._sMemberId = oEvent.getParameter("arguments").MemberID;
			
			// filter on team members
			var oFilter = new Filter("MemberTeam", FilterOperator.EQ, this._sId);
			oBinding.filter([ oFilter ]);
		},

		_changeNoDataTextToIndicateLoading: function (oList) {
			var sOldNoDataText = oList.getNoDataText();
			oList.setNoDataText("Loading...");
			oList.attachEventOnce("updateFinished", function() {oList.setNoDataText(sOldNoDataText);});
		},

		fnDataReceived: function() {
			var that = this,
				oList = this.getView().byId("MemberList");
			var aListItems = oList.getItems();
			aListItems.some(function(oItem) {
				if (oItem.getBindingContext().sPath === "/Member/" + that._sMemberId) {
					oList.setSelectedItem(oItem);
					return true;
				}
			});
		},

		handleMemberListSelect : function (oEvent) {
			this._showMember(oEvent);
		},

		handleMemberListItemPress : function (oEvent) {
			this._showMember(oEvent);
		},

		_showMember: function (oEvent) {
			var oBindContext;
			if (sap.ui.Device.system.phone) {
				oBindContext = oEvent.getSource().getBindingContext();
			} else {
				oBindContext = oEvent.getSource().getSelectedItem().getBindingContext();
			}
			var oModel = oBindContext.getModel();
			var sKey = oBindContext.getPath();
			// remove starting slash
			sKey = sKey.substr(1);
			var oNode = oModel.oData[sKey];
			var sMemberId = oNode.ID;
			this._router().navTo("Member", {TeamID: this._sId, MemberID: sMemberId}, !Device.system.phone);
		},
		
		onAddUser: function() {
			this._router().navTo("AddUser", {TeamID: this._sId}, !Device.system.phone);
		},
		
		onAddUserFloat: function (oEvent) {
			var that = this;
			if (!this._NewMemberDialog) {

				var oBundle = this.getOwnerComponent().getModel("i18n").getResourceBundle();				
				
				// create new member dialog
				var oInputView = sap.ui.view({
					id: "NewMember",
					viewName: "sap.ui.demo.mORMot.view.NewMember",
					type: "XML"
				});
				this._NewMemberDialog = new Dialog({
					title: oBundle.getText("MEMBER_ADD_PAGE_TITLE"),
					stretch: Device.system.phone,
					content: [
						oInputView
					],
					leftButton: new Button({
						text: oBundle.getText("SAVE_BUTTON_TEXT"),
						type: "Accept",
						press: function () {
							var bInputValid = oInputView.getController()._checkInput();
							if (bInputValid) {
								var oModel = that.getOwnerComponent().getModel();
								var mData = oInputView.getModel("newUser").getData();
								var oSelect = oInputView.byId("idSelectTeam");
								var oItem = oSelect.getSelectedItem();
								var iTeam = parseInt(oItem.getKey());	
								var mNewUser = {
										"FirstName": mData.FirstName,
										"LastName": mData.LastName,
										"Phone": mData.Phone,
										"Email": mData.Email,										
										"MemberTeam": iTeam      
								};
								oModel.create("/Member", mNewUser, {
									success: function() {
										that._NewMemberDialog.close();
										sap.m.MessageToast.show(oBundle.getText("ADD_MEMBER_SUCCESS_TEXT"));								
										//sap.m.MessageToast.show("Hello " + mNewUser.FirstName + " " + mNewUser.LastName)
									},
									error: function() {
										alert(oBundle.getText("ADD_MEMBER_FAILURE_TEXT"));
									}
								});
							}
						}
					}),
					rightButton: new Button({
						text: oBundle.getText("CANCEL_BUTTON_TEXT"),
						press: function () {
							that._NewMemberDialog.close();
						}
					})
				});

				this.getView().addDependent(this._NewMemberDialog);
			}

			// open new member dialog
			this._NewMemberDialog.open();
		}
		
	});
});
