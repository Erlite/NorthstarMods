globalize_all_functions

global enum HttpRequestMethod
{
    GET = 0,
    POST = 1
}

global struct HttpRequest
{
    /** Method used for this http request. */
    int method
    /** Base URL of this http request. */
    string baseUrl
    /** Headers used for this http request. Some may get overridden or ignored. */
    table<string, string> headers
    /** Query parameters for this http request. */
    table<string, string> queryParameters
    /** The content type of this http request. Defaults to text/plain & UTF-8 charset. */
    string contentType = "text/plain; charset=utf-8"
    /** The body of this http request. If set, will override queryParameters.*/
    string body
}

struct HttpRequestCallbacks
{
    void functionref( int, string, string ) onSuccess
    void functionref( int, string ) onFailure
}

table<int, HttpRequestCallbacks> pendingCallbacks

/**
 * Called from native when a HTTP request is successful.
 * This is internal and shouldn't be used.
 * Keep in mind that the success can be successful, but have a non-success status code.
 * @param handle The handle of the request we got a response for. 
 * @param statusCode The status code returned in the response.
 * @param body The body returned for GET requests.
 * @param headers The headers that were returned in the response.
 */
void function NSHandleSuccessfulHttpRequest(int handle, int statusCode, string body, string headers)
{
    if (handle in pendingCallbacks && pendingCallbacks[handle].onSuccess != null)
    {
        pendingCallbacks[handle].onSuccess(statusCode, body, headers)
    }

    delete pendingCallbacks[handle]
}

/**
 * Called from native when a HTTP request has failed.
 * This is internal and shouldn't be used.
 * @param handle The handle of the request that failed.
 * @param errorCode The error code returned by curl.
 * @param errorMessage The error message returned by curl.
 */
void function NSHandleFailedHttpRequest(int handle, int errorCode, string errorMessage)
{
    if (handle in pendingCallbacks && pendingCallbacks[handle].onFailure != null)
    {
        pendingCallbacks[handle].onFailure(errorCode, errorMessage)
    }

    delete pendingCallbacks[handle]
}

/**
 * Launch a HTTP request with the given request data.
 * This function is async, and the provided callbacks will be called when it is completed.
 * @param requestParameters The parameters to use for this request.
 * @param onSuccess The callback to execute if the request is successful.
 * @param onFailure The callback to execute if the request has failed.
 */
void function NSMakeHTTPRequest(HttpRequest requestParameters, void functionref( int, string, string ) onSuccess = null, void functionref( int, string ) onFailure = null)
{
    int handle = NS_InternalMakeHttpRequest(requestParameters.method, requestParameters.baseUrl, requestParameters.headers,
        requestParameters.queryParameters, requestParameters.contentType, requestParameters.body)

    if (handle != -1 && (onSuccess != null || onFailure != null))
    {
        HttpRequestCallbacks callback
        callback.onSuccess = onSuccess
        callback.onFailure = onFailure

        pendingCallbacks[handle] <- callback
    }
}

bool function NSIsSuccessHttpCode(int statusCode)
{
    return statusCode == 200
}

void function OnSucc(int code, string body, string headers)
{
    printt(code, body, headers)
}

void function OnFucc(int error, string message)
{
    printt(error, message)
}

#if SERVER
void function NSTestRequest()
{
    HttpRequest request = { ... }
    request.method = HttpRequestMethod.GET
    request.baseUrl = "https://northstar.tf/accounts/get_username"
    request.headers["hello"] <- "world"
    request.queryParameters["uid"] <- GetPlayerArray()[0].GetUID()
    request.contentType = "application/json"

    NSMakeHTTPRequest(request, OnSucc, OnFucc)
}
#endif