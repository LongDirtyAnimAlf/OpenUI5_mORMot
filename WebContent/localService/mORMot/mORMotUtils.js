/*!
 * UI development toolkit for HTML5 (OpenUI5)
 * (c) Copyright 2009-2015 SAP SE or an SAP affiliate company.
 * Licensed under the Apache License, Version 2.0 - see LICENSE.txt.
 */

/**
 * OData-based DataBinding Utility Class
 *
 * @namespace
 * @name sap.ui.model.odata
 * @public
 */

// Provides class sap.ui.model.odata.mORMotUtils
sap.ui.define(['jquery.sap.global', 'sap/ui/model/Sorter', 'sap/ui/core/format/DateFormat'],
	function(jQuery, Sorter, DateFormat) {
	"use strict";

	var rDecimal = /^([-+]?)0*(\d+)(\.\d+|)$/,
		rTrailingDecimal = /\.$/,
		rTrailingZeroes = /0+$/;

	// Static class

	/**
	 * @alias sap.ui.model.odata.mORMotUtils
	 * @namespace
	 * @public
	 */
	var mORMotUtils = function() {};

	/**
	 * Create URL parameters for sorting
	 * @param {array} aSorters an array of sap.ui.model.Sorter
	 * @return {string} the URL encoded sorter parameters
	 * @private
	 */
	mORMotUtils.createSortParams = function(aSorters) {
		var sSortParam;
		if (!aSorters || aSorters.length == 0) {
			return;
		}
		sSortParam = "$orderby=";
		for (var i = 0; i < aSorters.length; i++) {
			var oSorter = aSorters[i];
			if (oSorter instanceof Sorter) {
				sSortParam += oSorter.sPath;
				sSortParam += oSorter.bDescending ? "%20desc" : "%20asc";
				sSortParam += ",";
			}
		}
		//remove trailing comma
		sSortParam = sSortParam.slice(0, -1);
		return sSortParam;
	};	
	
	/**
	 * Converts a string or object-map with URL Parameters into an array.
	 * If vParams is an object map, it will be also encoded properly.
	 *
	 * @private
	 * @param {string|object|array} vParams
	 */
	mORMotUtils._createUrlParamsArray = function(vParams) {
		var aUrlParams, sType = jQuery.type(vParams), sParams;
		if (sType === "array") {
			return vParams;
		}

		aUrlParams = [];
		if (sType === "object") {
			sParams = this._encodeURLParameters(vParams);
			if (sParams) {
				aUrlParams.push(sParams);
			}
		} else if (sType === "string") {
			if (vParams) {
				aUrlParams.push(vParams);
			}
		}

		return aUrlParams;
	};

	/**
	 * Encode a map of parameters into a combined URL parameter string
	 *
	 * @param {map} mParams The map of parameters to encode
	 * @returns {string} sUrlParams The URL encoded parameters
	 * @private
	 */
	mORMotUtils._encodeURLParameters = function(mParams) {
		if (!mParams) {
			return "";
		}
		var aUrlParams = [];
		jQuery.each(mParams, function (sName, oValue) {
			if (jQuery.type(oValue) === "string") {
				oValue = encodeURIComponent(oValue);
			}
			sName = jQuery.sap.startsWith(sName,'$') ? sName : encodeURIComponent(sName);
			aUrlParams.push(sName + "=" + oValue);
		});
		return aUrlParams.join("&");
	};

	/**
	 * Adds an origin to the given service URL.
	 * If an origin is already present, it will only be replaced if the parameters object contains the flag "force: true".
	 * In case the URL already contains URL parameters, these will be kept.
	 * As a parameter, a sole alias is sufficient. The parameters vParameters.system and vParameters.client however have to be given in pairs.
	 * In case all three origin specifying parameters are given (system/client/alias), the alias has precedence.
	 * 
	 * Examples:
	 * setOrigin("/backend/service/url/", "DEMO_123");
	 * - result: /backend/service/url;o=DEMO_123/
	 * 
	 * setOrigin("/backend/service/url;o=OTHERSYS8?myUrlParam=true&x=4", {alias: "DEMO_123", force: true});
	 * - result /backend/service/url;o=DEMO_123?myUrlParam=true&x=4
	 * 
	 * setOrigin("/backend/service/url/", {system: "DEMO", client: 134});
	 * - result /backend/service/url;o=sid(DEMO.134)/
	 * 
	 * @param {string} sServiceURL the URL which will be enriched with an origin
	 * @param {object|string} vParameters if string then it is asumed its the system alias, else if the argument is an object then additional Parameters can be given
	 * @param {string} vParameters.alias the system alias which will be used as the origin
	 * @param {string} vParameters.system the system id which will be used as the origin
	 * @param {string} vParameters.client the system's client
	 * @param {string} vParameters.force setting this flag to 'true' overrides the already existing origin
	 * 
	 * @public
	 * @since 1.30.7
	 * @returns {string} the service URL with the added origin.
	 */
	mORMotUtils.setOrigin = function (sServiceURL, vParameters) {
		var sOrigin, sSystem, sClient;
			
		// if multi origin is set, do nothing
		if (!sServiceURL || !vParameters || sServiceURL.indexOf(";mo") > 0) {
			return sServiceURL;
		}
		
		// accept string as second argument -> only alias given
		if (typeof vParameters == "string") {
			sOrigin = vParameters;
		} else {
			// vParameters is an object
			sOrigin = vParameters.alias;
			
			if (!sOrigin) {
				sSystem = vParameters.system;
				sClient = vParameters.client;
				// sanity check
				if (!sSystem || !sClient) {
					jQuery.sap.log.warning("mORMotUtils.setOrigin: No Client or System ID given for Origin");
					return sServiceURL;
				} 
				sOrigin = "sid(" + sSystem + "." + sClient + ")";
			}
		}
		
		// determine the service base url and the url parameters
		var aUrlParts = sServiceURL.split("?");
		var sBaseURL = aUrlParts[0];
		var sURLParams = aUrlParts[1] ? "?" + aUrlParts[1] : "";
		
		//trim trailing "/" from url if present
		var sTrailingSlash = "";
		if (jQuery.sap.endsWith(sBaseURL, "/")) {
			sBaseURL = sBaseURL.substring(0, sBaseURL.length - 1);
			sTrailingSlash = "/"; // append the trailing slash later if necessary
		}
		
		// origin already included
		// regex will only match ";o=" occurrences which do not end in a slash "/" at the end of the string.
		// The last ";o=" occurrence at the end of the baseURL is the only origin that can match.
		var rOriginCheck = /(;o=[^/]+)$/;
		if (sBaseURL.match(rOriginCheck) != null) {
			// enforce new origin
			if (vParameters.force) {
				// same regex as above
				sBaseURL = sBaseURL.replace(rOriginCheck, ";o=" + sOrigin);
				return sBaseURL + sTrailingSlash + sURLParams;
			}
			//return the URL as it was
			return sServiceURL;
		}
		
		// new service url with origin
		sBaseURL = sBaseURL + ";o=" + sOrigin + sTrailingSlash;
		return sBaseURL + sURLParams;
	};

	/**
	 * Formats a JavaScript value according to the given
	 * <a href="http://www.odata.org/documentation/odata-version-2-0/overview#AbstractTypeSystem">
	 * EDM type</a>.
	 *
	 * @param {any} vValue the value to format
	 * @param {string} sType the EDM type (e.g. Edm.Decimal)
	 * @return {string} the formatted value
	 * @public
	 */
	mORMotUtils.formatValue = function(vValue, sType) {
		// Lazy creation of format objects
		if (!this.oDateTimeFormat) {
			this.oDateTimeFormat = DateFormat.getDateInstance({
				pattern: "'datetime'''yyyy-MM-dd'T'HH:mm:ss''"
			});
			this.oDateTimeOffsetFormat = DateFormat.getDateInstance({
				pattern: "'datetimeoffset'''yyyy-MM-dd'T'HH:mm:ss'Z'''"
			});
			this.oTimeFormat = DateFormat.getTimeInstance({
				pattern: "'time'''HH:mm:ss''"
			});
		}

		// null values should return the null literal
		if (vValue === null || vValue === undefined) {
			return "null";
		}
		return sValue;
	};

	/**
	 * Compares the given values using <code>===</code> and <code>></code>.
	 *
	 * @param {any} vValue1
	 *   the first value to compare
	 * @param {any} vValue2
	 *   the second value to compare
	 * @return {integer}
	 *   the result of the compare: <code>0</code> if the values are equal, <code>-1</code> if the
	 *   first value is smaller, <code>1</code> if the first value is larger, <code>NaN</code> if
	 *   they cannot be compared
	 */
	function simpleCompare(vValue1, vValue2) {
		if (vValue1 === vValue2) {
			return 0;
		}
		if (vValue1 === null || vValue2 === null
				|| vValue1 === undefined || vValue2 === undefined) {
			return NaN;
		}
		return vValue1 > vValue2 ? 1 : -1;
	}

	/**
	 * Parses a decimal given in a string.
	 *
	 * @param {string} sValue
	 *   the value
	 * @returns {object}
	 *   the result with the sign in <code>sign</code>, the number of integer digits in
	 *   <code>integerLength</code> and the trimmed absolute value in <code>abs</code>
	 */
	function parseDecimal(sValue) {
		var aMatches;

		if (typeof sValue !== "string") {
			return undefined;
		}
		aMatches = rDecimal.exec(sValue);
		if (!aMatches) {
			return undefined;
		}
		return {
			sign: aMatches[1] === "-" ? -1 : 1,
			integerLength: aMatches[2].length,
			// remove trailing decimal zeroes and poss. the point afterwards
			abs: aMatches[2] + aMatches[3].replace(rTrailingZeroes, "")
					.replace(rTrailingDecimal, "")
		};
	}

	/**
	 * Compares two decimal values given as strings.
	 *
	 * @param {string} sValue1
	 *   the first value to compare
	 * @param {string} sValue2
	 *   the second value to compare
	 * @return {integer}
	 *   the result of the compare: <code>0</code> if the values are equal, <code>-1</code> if the
	 *   first value is smaller, <code>1</code> if the first value is larger, <code>NaN</code> if
	 *   they cannot be compared
	 */
	function decimalCompare(sValue1, sValue2) {
		var oDecimal1, oDecimal2, iResult;

		if (sValue1 === sValue2) {
			return 0;
		}
		oDecimal1 = parseDecimal(sValue1);
		oDecimal2 = parseDecimal(sValue2);
		if (!oDecimal1 || !oDecimal2) {
			return NaN;
		}
		if (oDecimal1.sign !== oDecimal2.sign) {
			return oDecimal1.sign > oDecimal2.sign ? 1 : -1;
		}
		// So they have the same sign.
		// If the number of integer digits equals, we can simply compare the strings
		iResult = simpleCompare(oDecimal1.integerLength, oDecimal2.integerLength)
			|| simpleCompare(oDecimal1.abs, oDecimal2.abs);
		return oDecimal1.sign * iResult;
	}

	/**
	 * Extracts the milliseconds if the value is a date/time instance.
	 * @param {any} vValue
	 *   the value (may be <code>undefined</code> or <code>null</code>)
	 * @returns {any}
	 *   the number of milliseconds or the value itself
	 */
	function extractMilliseconds(vValue) {
		if (vValue instanceof Date) {
			return vValue.getTime();
		}
		return vValue;
	}

	/**
	 * Compares the given OData values based on their type. All date and time types can also be
	 * compared with a number. This number is then interpreted as the number of milliseconds that
	 * the corresponding date or time object should hold.
	 *
	 * @param {any} vValue1
	 *   the first value to compare
	 * @param {any} vValue2
	 *   the second value to compare
	 * @param {string} [bAsDecimal=false]
	 *   if <code>true</code>, the string values <code>vValue1</code> and <code>vValue2</code> are
	 *   compared as a decimal number (only sign, integer and fraction digits; no exponential
	 *   format). Otherwise they are recognized by looking at their types.
	 * @return {integer}
	 *   the result of the compare: <code>0</code> if the values are equal, <code>-1</code> if the
	 *   first value is smaller, <code>1</code> if the first value is larger, <code>NaN</code> if
	 *   they cannot be compared
	 * @since 1.29.1
	 * @public
	 */
	mORMotUtils.compare = function (vValue1, vValue2, bAsDecimal) {
		return bAsDecimal ? decimalCompare(vValue1, vValue2)
			: simpleCompare(extractMilliseconds(vValue1), extractMilliseconds(vValue2));
	};

	return mORMotUtils;

}, /* bExport= */ true);
