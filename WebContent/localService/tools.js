/**
 * get service url
 * @param sServiceUrl
 * @returns
 */
function getServiceUrl1(sServiceUrl) {
  if (window.location.hostname == "localhost") {
      return "http://localhost:8080" + sServiceUrl;
  } else {
      return "http://ec2-54-194-211-233.eu-west-1.compute.amazonaws.com:8080" + sServiceUrl;
  }
};

/**
 * get service url 2
 * @param sServiceUrl
 * @returns
 */
function getServiceUrl2(sServiceUrl) {  
    var sOrigin = window.location.protocol + "//" + window.location.hostname + (window.location.port ? ":" + window.location.port : "");  
    if (!jQuery.sap.startsWith(sServiceUrl, sOrigin)) {  
         return "proxy/" + sServiceUrl.replace("://", "/");  
    } else {  
          return sServiceUrl.substring(sOrigin.length) ; 
    }  
} 
 
