sap.ui.controller("sap.ui.demo.mORMot.view.NewTeam", {

	onInit : function () {
		var oModel = new sap.ui.model.json.JSONModel({});
		this.getView().setModel(oModel, "newTeam");

		// handle data binding validation results
		sap.ui.getCore().attachValidationError(
			function (oEvent) {
				var oElement = oEvent.getParameter("element");
				if (oElement.setValueState) {
					oElement.setValueState(sap.ui.core.ValueState.Error);
				}
			}
		);
		sap.ui.getCore().attachValidationSuccess(
			function (oEvent) {
				var oElement = oEvent.getParameter("element");
				if (oElement.setValueState) {
					oElement.setValueState(sap.ui.core.ValueState.None);
				}
			}
		);
	},
	
	_checkInput : function () {
		
		var oView = this.getView();
		var oInput = oView.byId("inputName");
		
		oInput.getValue() ? oInput.setValueState(sap.ui.core.ValueState.None) : oInput.setValueState(sap.ui.core.ValueState.Error);

		if (oInput.getValueState() === sap.ui.core.ValueState.Error) {
			return false;
		}
		
		return true;
	}
});
