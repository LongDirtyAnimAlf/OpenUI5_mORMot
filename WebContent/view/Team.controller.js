sap.ui.define([
	'sap/ui/demo/mORMot/localService/BaseController',
	'sap/ui/demo/mORMot/model/formatter',
	'sap/ui/Device',
	'sap/ui/model/Filter',
	'sap/ui/model/FilterOperator'
], function (BaseController,
			 formatter,
			 Device,
			 Filter,
			 FilterOperator) {
	"use strict";

	var sId=0;
	
	return BaseController.extend("sap.ui.demo.mORMot.view.Team", {
		formatter : formatter,

		onInit : function () {
			this._router().getRoute("Team").attachMatched(this._loadTeam, this);
		},
		
		_loadTeam : function(oEvent) {
			var oMemberList = this.getView().byId("MemberList");
			this._changeNoDataTextToIndicateLoading(oMemberList);
			var oBinding = oMemberList.getBinding("items");
			oBinding.attachDataReceived(this.fnDataReceived, this);
			//sId = oEvent.getParameter("arguments").TeamID;
			sId = oEvent.getParameters().arguments.TeamID
			// not available !!
			this._sMemberId = oEvent.getParameter("arguments").MemberID;
			
			this.getView().byId("page").setTitle(sId);
			
			// filter on team members
			var oFilter = new Filter("MemberTeam", FilterOperator.EQ, sId);
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
			this._router().navTo("Member", {TeamID: sId, MemberID: sMemberId}, !Device.system.phone);
		}
	});
});
