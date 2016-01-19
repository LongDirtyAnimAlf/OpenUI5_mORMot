sap.ui.define(["sap/ui/core/format/NumberFormat",
               "sap/ui/core/format/DateFormat"
               ], function (NumberFormat) {
	"use strict";

	var formatter = {
			
		price: function (value) {
			var numberFormat = NumberFormat.getFloatInstance({
				maxFractionDigits: 2,
				minFractionDigits: 2,
				groupingEnabled: true,
				groupingSeparator: ".",
				decimalSeparator: ","
			});
			return numberFormat.format(value);
		},
	
		date : function (value) {
			if (value) {
				var oDateFormat = sap.ui.core.format.DateFormat.getDateTimeInstance({pattern: "yyyy-MM-dd"}); 
				return oDateFormat.format(new Date(value));
			} else {
				return value;
			}
		},
		
		quantity :  function (value) {
			try {
				return (value) ? parseFloat(value).toFixed(0) : value;
			} catch (err) {
				return "Not-A-Number";
			}
		},
		
		uppercaseFirstChar : function(sStr) {
			return sStr.charAt(0).toUpperCase() + sStr.slice(1);
		},

		discontinuedStatusState : function(sDate) {
			return sDate ? "Error" : "None";
		},

		discontinuedStatusValue : function(sDate) {
			return sDate ? "Discontinued" : "";
		},

		currencyValue : function (value) {
			return parseFloat(value).toFixed(2);
		},
		
		imageURL : function (value) {
			return value+'/Image';
		}		
		
	
	};
	return formatter;
});
