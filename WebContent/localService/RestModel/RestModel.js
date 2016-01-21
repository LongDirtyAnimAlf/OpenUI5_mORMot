/*!
 * UI development toolkit for HTML5 (OpenUI5)
 * (c) Copyright 2009-2015 SAP SE or an SAP affiliate company.
 * Licensed under the Apache License, Version 2.0 - see LICENSE.txt.
 */

/**
 * REST-based Data Binding
 * This model an use a plain REST source without metadata and a standard REST data layout
 * (c) Copyright Don.  
 *
 * @namespace
 * @name sap.ui.model.rest
 * @public
 */

//Provides class sap.ui.model.rest.RestModel
sap.ui.define([
	'jquery.sap.global',
    'sap/ui/model/odata/v2/ODataModel',
    'sap/ui/model/Context',
    './RestMetadata',
    'sap/ui/model/odata/ODataUtils',
	'sap/ui/model/odata/CountMode', 'sap/ui/model/odata/UpdateMethod', 'sap/ui/model/odata/OperationMode'
	], function(
		jQuery,
		ODataModel,
		Context,
		RestMetadata,
		ODataUtils,
		CountMode, UpdateMethod, OperationMode
		) {

	"use strict";


	/**
	 * Constructor for a new RestModel.
	 *
	 * @class
	 * (OData-)Model implementation for plain rest format
	 *
	 * @extends sap.ui.model.ODataModel
	 *
	 * @author Don
	 * @version 1.32.9
	 *
	 * @constructor
	 * @public
	 * @alias sap.ui.model.rest.RestModel
	 */
	var RestModel = ODataModel.extend("sap.ui.model.rest.RestModel", /** @lends sap.ui.model.rest.RestModel.prototype */ {

		constructor : function(sServiceUrl, mParameters) {
			
			var bmORMotRootResponse = false;
			var sKey;
			
			ODataModel.apply(this, arguments);

			// set some default to non odata  features
			this.bUseBatch = false;
			this.bJSON = true;
			this.sDefaultCountMode = CountMode.None;
			this.sDefaultOperationMode = OperationMode.Client;
			this.sDefaultUpdateMethod = UpdateMethod.Put;
			
			this.bTokenHandling = false;			
			
			this.oHeaders["Accept"] = "application/json";
			
			// remove trailing path delimiter if there
			this.sServiceUrl = this.sServiceUrl.replace(/\/$/g, "");			
			
			// destroy current metadata object
			this.oMetadata.destroy();
			
			// create new (dummy) metadata object
			// dummy could even be used to load dataobjects from REST, but not yet now ... work in progress
			this.oMetadata = new RestMetadata(
				"",{
					async: false,
					user: "",
					password: "",
					headers: "",
					namespaces: null,
					withCredentials: false
				} 					
			);

			this.oServiceData.oMetadata = this.oMetadata;
			this.pAnnotationsLoaded = this.oMetadata.loaded();

			this.oMetadata.bLoaded = true;
			this.oMetadata.bFailed = false;			
		},
		metadata : {
			publicMethods : ["setKey","setmORMotRootResponse"]
		}
	});

	RestModel.prototype.setKey = function(sKey) {
		this.sKey = sKey;
	};
	
	RestModel.prototype.setmORMotRootResponse = function(bValue) {
		this.bmORMotRootResponse = bValue;
	};  	
	
	RestModel.prototype._initializeMetadata = function(bDelayEvent) {
		this.oMetadata.bLoaded = true;
		this.oMetadata.bFailed = false;			
	};

	// adapted for non odata REST servers
	// not finshed yet
	RestModel.prototype.createCustomParams = function(mParameters) {
		var aCustomParams = [],
		bSelect = false,
		mCustomQueryOptions,
		mSupportedParams = {
				select: true
		};
		
		for (var sName in mParameters) {
			if (sName in mSupportedParams) {
				aCustomParams.push(sName + "=" + jQuery.sap.encodeURL(mParameters[sName]));
				bSelect = (bSelect || sName=="select");
			}
			if (sName === "custom") {
				mCustomQueryOptions = mParameters[sName];
				for (sName in mCustomQueryOptions) {
					aCustomParams.push(sName + "=" + jQuery.sap.encodeURL(mCustomQueryOptions[sName]));
				}
			}
		}
		
		if (!bSelect && this.bmORMotRootResponse) {
			//aCustomParams.push("select=" + jQuery.sap.encodeURL(''));
			//aCustomParams.push("select=" + jQuery.sap.encodeURL('*'));
		}
		return aCustomParams.join("&");
	};

	// adapted for non odata REST servers	
	RestModel.prototype._getKey = function(oObject) {
		var sKey, sURI, that=this;
		if (oObject instanceof Context) {
			sKey = oObject.getPath().substr(1);
		} else if (oObject && oObject.__metadata && oObject.__metadata.uri) {
			sURI = oObject.__metadata.uri;			
			sKey = sURI.replace(that.sServiceUrl,"");
			if (jQuery.sap.startsWith(sKey, "/")) {
				sKey = sKey.substr(1);	
			};
		}
		return sKey;
	};

	// adapted for non odata REST servers	
	RestModel.prototype.getKey = function(oObject) {
		return this._getKey(oObject);
	};

	
	// adapted for non odata REST servers 	
	RestModel.prototype._getObject = function(sPath, oContext, bOriginalValue) {
		var oNode = this.isLegacySyntax() ? this.oData : null, oChangedNode, oOrigNode,
			sResolvedPath = this.resolve(sPath, oContext),
			iSeparator, sDataPath, sMetaPath, oMetaContext, oMetaModel;
		
		var sKey;
		var sDataKey;
		
		if (!sResolvedPath) {
			return oNode;
		}

		var iIndex;
		var iDataIndex;
		var aParts = sResolvedPath.split("/");
		var iLength = aParts.length;

		// finding the key is complicated, when the REST scheme is not exactly known
		// below an algorithm to perform this task as good as possible !!
		// remains tricky
		
		iIndex = 1;
		iDataIndex = 1;
		while (aParts[iIndex] && (iIndex<(iLength-1) || (iIndex<3))) {
			if (sKey) {
				sKey = sKey + "/" + aParts[iIndex];				
			} else {
				sKey = aParts[iIndex];
			}
			iIndex++;
			if (this.oData[sKey]) {
				sDataKey = sKey;
				iDataIndex = iIndex;
			}
		}

		oOrigNode = this.oData[sKey];
		if (!oOrigNode && sDataKey && ((iIndex-iDataIndex)==1)) {
			sKey = sDataKey;
			iIndex = iDataIndex;
		}

		oOrigNode = this.oData[sKey];
		oChangedNode = this.mChangedEntities[sKey];

		aParts.splice(0,(iIndex));
		
		if (!bOriginalValue) {
			oNode = !sKey ? this.oData : oChangedNode || oOrigNode;
		} else {
			oNode = !sKey ? this.oData : oOrigNode;
		}

		iIndex = 0;		
		while (oNode && aParts[iIndex]) {
			var bHasChange = oChangedNode && oChangedNode.hasOwnProperty(aParts[iIndex]);
			oChangedNode = oChangedNode && oChangedNode[aParts[iIndex]];
			oOrigNode = oOrigNode && oOrigNode[aParts[iIndex]];
			oNode = bOriginalValue || !bHasChange ? oOrigNode : oChangedNode;
			if (oNode) {
				if (oNode.__ref) {
					oChangedNode = this.mChangedEntities[oNode.__ref];
					oOrigNode =  this.oData[oNode.__ref];
					oNode =  bOriginalValue ? oOrigNode : oChangedNode || oOrigNode;
				} else if (oNode.__list) {
					oNode = oNode.__list;
				} else if (oNode.__deferred) {
					// set to undefined and not to null because navigation properties can have a null value
					oNode = undefined;
				}
			}
			iIndex++;
		}
		//if we have a changed Entity we need to extend it with the backend data
		if (this._getKey(oChangedNode)) {
			oNode =  bOriginalValue ? oOrigNode : jQuery.sap.extend(true, {}, oOrigNode, oChangedNode);
		}
		return oNode;
	};
	
	// adapted for standard jquery ajax command for sending and retrieving data and compensate for missing metadata
	RestModel.prototype._submitRequest = function(oRequest, fnSuccess, fnError){
		var that = this, oHandler, oRequestHandle, bAborted;

		function _handleSuccess(oData, oResponse, jqXHR) {

			var sUri = oRequest.url;

			var sPath = sUri.replace(that.sServiceUrl,"");
			//in batch requests all paths are relative
			if (!jQuery.sap.startsWith(sPath,'/')) {
				sPath = '/' + sPath;
			}

			sPath = that._normalizePath(sPath);

			// decrease laundering
			that.decreaseLaundering(sPath, oRequest.data);
			
			// mORMot REST server: after a POST (new data), the new ID can be found here:
			var sNewKey = jqXHR.getResponseHeader("Location");
			if (sNewKey) {
				sPath = "/"+sNewKey
			}

			var oEntityType = that.oMetadata._getEntityTypeByPath(sPath);			

			var aNewResponse = {};			
			
			// add uri and property to mimic odata metadata results ... bit of a trick ... ;-)
			if (oData) {
				
				var sKey = oEntityType.key.propertyRef[0].name;
				
				var oProperty = oEntityType.property;			
				var oNewProperty = [];
				
				if (jQuery.sap.endsWith(that.sServiceUrl,'/')) {
					sPath = that.sServiceUrl + sPath.substr(1);
				} else {
					sPath = that.sServiceUrl + sPath;
				}

				if (jQuery.isArray(oData)) {
					for (var sName in oData[0]) {
						oNewProperty.push({name : sName});
					}
					for (var attr in oData) {
						oData[attr].__metadata = {
							uri: sPath+"/"+oData[attr][sKey],
							id: sPath+"/"+oData[attr][sKey]
						}
					}
					aNewResponse.data = { results:oData};
				} else {
					for (var sName in oData) {
						oNewProperty.push({name : sName});
					}
					oData.__metadata = {
							uri: sPath,
							id: sPath
					}
					aNewResponse.data = oData;
				}
				// generate property namespace info on the fly				
				$.extend(true, oProperty, oNewProperty);
			}

			aNewResponse.statusCode = jqXHR.status;
			aNewResponse.headers = jqXHR.getAllResponseHeaders();

			aNewResponse.url = oRequest.url;
			aNewResponse.async = oRequest.async;
			
			if (!aNewResponse.data) {
				aNewResponse.data = oRequest.data			
			}
			
			if (!aNewResponse.data && aNewResponse.statusCode==200) {
				aNewResponse.statusCode = 204;			
			}

			if (fnSuccess) {
				fnSuccess(oData, aNewResponse);
			}
		}

		function _handleError(oError,textStatus,errorThrown ) {
			
			// If error is a 403 with XSRF token "Required" reset the token and retry sending request
			if (that.bTokenHandling && oError) {
				var sToken = that._getHeader("x-csrf-token", oError.getAllResponseHeaders());
				if (!oRequest.bTokenReset && oError.status == '403' && sToken && sToken.toLowerCase() === "required") {
					that.resetSecurityToken();
					oRequest.bTokenReset = true;
					_submitWithToken();
					return;
				}
			}
			if (fnError) {
				fnError(oError,oRequest);
			}
		}

		function _readyForRequest(oRequest) {
			if (that.bTokenHandling && oRequest.method !== "GET") {
				that.pReadyForRequest = that.securityTokenAvailable();
			}
			return that.pReadyForRequest;
		}

		function _submitWithToken() {
			// request token only if we have change operations or batch requests
			// token needs to be set directly on request headers, as request is already created
			_readyForRequest(oRequest).then(function(sToken) {
				// Check bTokenHandling again, as updating the token might disable token handling
				if (that.bTokenHandling) {
					oRequest.headers["x-csrf-token"] = sToken;
				}
				_submit();
			}, function() {
				_submit();
			});
		}

		var fireEvent = function(sType, oRequest, oError) {
			var oEventInfo,
				aRequests = oRequest.eventInfo.requests;
			if (aRequests) {
				jQuery.each(aRequests, function(i, oRequest) {
					if (jQuery.isArray(oRequest)) {
						jQuery.each(oRequest, function(i, oRequest) {
							oEventInfo = that._createEventInfo(oRequest.request, oError);
							that["fireRequest" + sType](oEventInfo);
						});
					} else {
						oEventInfo = that._createEventInfo(oRequest.request, oError);
						that["fireRequest" + sType](oEventInfo);
					}
				});

				oEventInfo = that._createEventInfo(oRequest, oError, aRequests);
				that["fireBatchRequest" + sType](oEventInfo);
			} else {
				oEventInfo = that._createEventInfo(oRequest, oError, aRequests);
				that["fireRequest" + sType](oEventInfo);
			}
		};

		function _submit() {
			oRequestHandle = that._request(oRequest, _handleSuccess, _handleError);
			if (oRequest.eventInfo) {
				fireEvent("Sent", oRequest, null);
				delete oRequest.eventInfo;
			}
			if (bAborted) {
				oRequestHandle.abort();
			}
		}

		_submitWithToken();

		return {
			abort: function() {
				if (oRequestHandle) {
					oRequestHandle.abort();
				}
				bAborted = true;
			}
		};
	};


	// adapted for standard jquery ajax command for sending and retrieving data	
	RestModel.prototype._handleError = function(oError, oRequest) {
		var mParameters = {}, /* fnHandler, */ sToken;
		var sErrorMsg = "The following problem occurred: " + oError.responseJSON.errorText;
		
		mParameters.message = oError.responseJSON.errorText;

		if (this.bTokenHandling) {
			// if XSRFToken is not valid we get 403 with the x-csrf-token header : Required.
			// a new token will be fetched in the refresh afterwards.
			sToken = this._getHeader("x-csrf-token", oError.getAllResponseHeaders());
			if (oError.status == '403' && sToken && sToken.toLowerCase() === "required") {
				this.resetSecurityToken();
			}
		}

		//if (textStatus == "timeout") {
		//	create_notify("msgs", { title:'Timeout', text:'Sorry, server is down at the moment. Try again later', icon:'server_down.gif' });
		//}
		
		if (oError.responseJSON.errorText == "Forbidden") {
			// a bit rough, needed to get an abort in case of a login failure !!
			//mParameters.statusCode = 0;
		} else {
		}
		
		mParameters.statusCode = oError.status;		
		mParameters.statusText = oError.statusText;
		mParameters.headers = oError.getAllResponseHeaders();
		mParameters.responseText = oError.responseText;

		jQuery.sap.log.fatal(sErrorMsg);
		
		return mParameters;
	};

	
	// adapted for standard jquery ajax command for sending and retrieving data	
	RestModel.prototype._createRequest = function(sUrl, sMethod, mHeaders, oData, sETag, bAsync) {
		bAsync = bAsync !== false;

		/* make sure to set content type header for POST/PUT requests when using JSON
		 * may be removed as later gateway versions support this */
		if (sMethod !== "DELETE" && sMethod !== "GET") {
			mHeaders["Content-Type"] = "application/json; charset=UTF-8";
		}

		// Set Accept header for $count requests
		if (sUrl.indexOf("$count") > -1) {
			mHeaders["Accept"] = "text/plain, */*;q=0.5";
		}

		// format handling
		if (sMethod === "MERGE" && !this.bUseBatch) {
			mHeaders["x-http-method"] = "MERGE";
			sMethod = "POST";
		}

		var oRequest = {
				headers : mHeaders,
				url : sUrl,
				requestUri : sUrl,
				method : sMethod,
				username: this.sUser,
				password: this.sPassword,
				async: bAsync
		};

		if (oData) {
			oRequest.data = oData;
		}

		if (this.bWithCredentials) {
			oRequest.withCredentials = this.bWithCredentials;
		}

		oRequest.requestID = this._createRequestID();

		return oRequest;
	};

	// send and retrieve data with standard jquery ajax 
	RestModel.prototype._request = function(oRequest, fnSuccess, fnError) {

		
		// Added: ignore root response for mORMot ... remove trailing path delimiter
		if (
			this.bDestroyed
			//||
			//(oRequest.url.replace(/\/$/g, "")==this.sServiceUrl)
			//||
			//(oRequest.method=="HEAD")
			||
			(oRequest.url.indexOf("null") > -1)
		) {
			return {
				abort: function() {}
			};
		}

		var that = this;

		function wrapHandler(fn) {
			return function() {
				// request finished, remove request handle from pending request array
				var iIndex = jQuery.inArray(oRequestHandle, that.aPendingRequestHandles);
				if (iIndex > -1) {
					that.aPendingRequestHandles.splice(iIndex, 1);
				}

				// call original handler method
				if (!(oRequestHandle && oRequestHandle.bSuppressErrorHandlerCall)) {
					fn.apply(this, arguments);
				}
			};
		}

		oRequest.success = wrapHandler(fnSuccess || oRequest.success);
		oRequest.error = wrapHandler(fnError || oRequest.error);

		oRequest.datatype = 'json';
		//oRequest.datatype = 'jsonp';		

		delete oRequest.headers["DataServiceVersion"]; // Remove odata header before call
		delete oRequest.headers["MaxDataServiceVersion"]; // Remove odata header before call
		
		if (oRequest.data) {
			if (oRequest.data.__metadata) {
				delete oRequest.data.__metadata;
			}
			if (!jQuery.sap.startsWith(oRequest.headers["Content-Type"], "application/octet-stream")) {
				oRequest.data=JSON.stringify(oRequest.data);
			} 			
		}
		
		//oRequest.crossDomain = true;
		
		//oRequest.beforeSend = function(xmlHttpRequest) {
		//        xmlHttpRequest.withCredentials = true;
	    //}
		
		oRequest.url = this.signUrl(oRequest.url);
		
		var oRequestHandle = jQuery.ajax(oRequest);

		// add request handle to array and return it (only for async requests)
		if (oRequest.async !== false) {
			this.aPendingRequestHandles.push(oRequestHandle);
		}

		return oRequestHandle;
	};

	RestModel.prototype.isList = function(sPath, oContext) {
		sPath = this.resolve(sPath, oContext);
		return jQuery.isArray(this._getObject(sPath)); 		
	};
	
	RestModel.prototype._parseResponse = function(oResponse, oRequest, mGetEntities, mChangeEntities) {
		// no standard REST message parser in existence 
		// console.log("Response:");
		// console.log(oResponse);		
	};

	// create metadata from path and parameters
	// key has to be defined in  parameters
	// e.g.
	// path : sSomePath,
	// parameters :{
	// 	key:'id'
	// }
	RestModel.prototype._createmetakey = function(sPath, mParameters) {
		var that = this;

		// only process absolute paths
		if (!jQuery.sap.startsWith(sPath, "/")) {
			return;
		}		

		// generate namespace info on the fly
		
		var sKey;
		if (mParameters && mParameters.key) {
			sKey=mParameters.key;			
		} else {
			if (that.sKey) {
				sKey = that.sKey;
			} else {
				// default value of key
				sKey = "ID";
			}
		}
		
		 
		
		var aParts = sPath.replace(/\/$/g, "").split("/");
		var i = (aParts.length)-1;
		
		i = i - ((i+1) % 2);
		
		var sName = aParts[i];
		//var sNewPath = aParts[i-2];		

		//sName = sPath.substr(1);
		//sName = sPath.substr(sPath.lastIndexOf("/") + 1);
		if (!sName) {
			return;
		}
		var oSchema = this.oMetadata.oMetadata.dataServices.schema[0];
		
		var bFound;
		
		bFound = false;
		var aEntityType = oSchema.entityType;		
		jQuery.each(aEntityType, function(i, oEntity) {
			if (oEntity.name === sName) {
				bFound = true;
			}
		});
		if (!bFound) {
			var oEntityObject = {};
			oEntityObject.namespace = oSchema.namespace;
			oEntityObject.name = sName;
			oEntityObject.key = {propertyRef : [{name : sKey}]};
			oEntityObject.entityType = oEntityObject.namespace+'.'+oEntityObject.name;
			oEntityObject.property = [];		
			aEntityType.push(oEntityObject);
		}
				
		bFound = false;
		var aEntitySet = oSchema.entityContainer[0].entitySet;		
		jQuery.each(aEntitySet, function(i, oEntity) {
			if (oEntity.name === sName) {
				bFound = true;
			}
		});
		if (!bFound) {
			var oEntitySetObject = {
					entityType : oSchema.namespace+"."+sName,
					name : sName
			};			
			aEntitySet.push(oEntitySetObject);
		}
		
	};                               	
	
	// intercept creation of bindings to create metadata	
	RestModel.prototype.createBindingContext = function(sPath, oContext, mParameters, fnCallBack, bReload) {
		// get key from params or settings
		// mimics metadata info
		//this._createmetakey(sPath, mParameters);
		return ODataModel.prototype.createBindingContext.apply(this, arguments);		
	};
	
	RestModel.prototype.bindProperty = function(sPath, oContext, mParameters) {
		//this._createmetakey(sPath, mParameters);
		//console.log("oContext");		
		//console.log(oContext);
		return ODataModel.prototype.bindProperty.apply(this, arguments);
	};	
	
	// intercept creation of bindings to create metadata	
	RestModel.prototype.bindList = function(sPath, oContext, aSorters, aFilters, mParameters) {
		// get key from params or settings
		// mimics metadata info
		this._createmetakey(sPath, mParameters);
		//mParameters.faultTolerant = true;
		return ODataModel.prototype.bindList.apply(this, [sPath, oContext, aSorters, aFilters, mParameters]);		
		//return ODataModel.prototype.bindList.apply(this, arguments);		
	};

	// intercept creation of bindings to create metadata	
	RestModel.prototype.bindTree = function(sPath, oContext, aFilters, mParameters, aSorters) {
		// get key from params or settings
		// mimics metadata info
		this._createmetakey(sPath, mParameters);
		//mParameters.faultTolerant = true;		
		return ODataModel.prototype.bindTree.apply(this, [sPath, oContext, aFilters, mParameters, aSorters]);		
		//return ODataModel.prototype.bindTree.apply(this, arguments);		
	};

	// first start of key creation
	// needed for full read/write
	// on my todo list
	RestModel.prototype.createKey = function(sCollection, oKeyProperties) {
		var oEntityType = this.oMetadata._getEntityTypeByPath(sCollection),
		sKey = sCollection;
		jQuery.sap.assert(oEntityType, "Could not find entity type of collection \"" + sCollection + "\" in service metadata!");
		sKey += "/"+oEntityType.key.propertyRef[0].name;
		return sKey;
	};
	
	// Override resolveGroup .. it errors out while changing properties !!
	ODataModel.prototype._resolveGroup = function(sKey) {
		var oChangeGroup, sGroupId, sChangeSetId;
		oChangeGroup = this.mChangeGroups['*'];
		sGroupId = oChangeGroup.groupId;
		sChangeSetId = oChangeGroup.single ? jQuery.sap.uid() : oChangeGroup.changeSetId;
		return {groupId: sGroupId, changeSetId: sChangeSetId};
	};
	
	RestModel.prototype.updateBlob = function(sPath, mParameters) {
		var oBlobData, mHeaders, fnSuccess, fnError, oRequest, sUrl, handleSuccess,
		sMethod, mRequests, sGroupId, sChangeSetId,
		that = this;

		if (mParameters) {
			oBlobData = mParameters.BlobData;
			fnSuccess = mParameters.success;
			fnError   = mParameters.error;
		}
		
		sMethod = "PUT";
		mHeaders = this._getHeaders(mHeaders);

		handleSuccess = function(oData, oResponse) {
			if (fnSuccess) {
				fnSuccess(oData, oResponse);
			}
		};

		return this._processRequest(function() {
			sUrl = that._createRequestUrl(sPath);
			oRequest = that._createRequest(sUrl, sMethod, mHeaders);
			mHeaders["Content-Type"] = "application/octet-stream";			
			mRequests = that.mRequests;
			oRequest.data = oBlobData;			
			oRequest.processData = false;			
			that._pushToRequestQueue(mRequests, sGroupId, sChangeSetId, oRequest, handleSuccess, fnError);
			return oRequest;
		});
	};

	RestModel.prototype.signUrl = function(sUrl) {
		var sKey = sUrl.replace(this.mORMotClient.ServerURL,"");
		sKey = sKey.substr(1);		
		return this.mORMotClient.ServerURL +"/" + this.mORMotClient.signUrl(sKey);		
	};
	
	return RestModel;
});
