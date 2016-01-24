jQuery.sap.declare("model.Config");

model.Config = {};

(function() {
	var responderOn = jQuery.sap.getUriParameters().get("responderOn");
	model.Config.isMock = ("true" === responderOn);
})();

model.Config.getServiceUrl = function(sServiceUrl) {
  // If the path doesn't have a leading slash, add one
  if (sServiceUrl) {
	  sServiceUrl = sServiceUrl.charAt(0) !== "/" ? "/" + sServiceUrl : sServiceUrl;
	  return model.Config.getHost() + sServiceUrl;	  
  } else {
	  return model.Config.getHost();
  }
};

model.Config.getUser = function() {
	return "";

};

model.Config.getPwd = function() {
	return "";
};

model.Config.getHost = function() {
  if (window.location.hostname == "localhost") {
      return "http://localhost:8080";
  } else {
      // the real webaddress of the mORMot REST server
      //return "http://ec2-54-194-211-233.eu-west-1.compute.amazonaws.com:8080";
      return "http://www.consulab.nl:8080";      
  }
};

// @ sourceURL=./model/Config.js
