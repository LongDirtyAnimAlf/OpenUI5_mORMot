sap.ui.controller("sap.ui.demo.mORMot.view.NewMember", {

	onInit : function () {
		var oModel = new sap.ui.model.json.JSONModel({});
		this.getView().setModel(oModel, "newUser");

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
		var aInputs = [
			oView.byId("inputFirstName"),
			oView.byId("inputLastName")
		];
		
		// make sure all fields are not empty 
		// (this is not done by data binding validation
		//  as data binding only runs on changing values)
		jQuery.each(aInputs, function (i, oInput) {
			if (!oInput.getValue()) {
				oInput.setValueState(sap.ui.core.ValueState.Error);
			}
		});

		// check that all fields are ok
		for (var i = 0 ; i < aInputs.length ; i++) {
			if (aInputs[i].getValueState() === sap.ui.core.ValueState.Error) {
				return false;
			}
		}
		return true;
	}
});
