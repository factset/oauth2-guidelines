# FactSet APIs and OAuth 2.0

FactSet APIs use OAuth 2.0 for authentication and authorization. Public and Confidential Clients are supported, along with the Client Credentials and the Authorization Code flows. This document specifies the requirements of Client applications, and it details the flows, including the expected properties in all messages. It provides the location of the Discovery Document, containing the OAuth 2.0 URIs for the Authorization and the Token endpoints. And, with the aid of bash shell scripts in this repository, this document explains how to test.

## Table of Contents

- [Client Types](#client-types)
  * [Public Clients](#public-clients)
  * [Confidential Clients](#confidential-clients)
- [Discovery Document](#discovery-document)
- [JSON Web Signature (JWS)](#json-web-signature-jws)
  * [JWS Components](#jws-components)
    + [JOSE Header](#jose-header)
    + [JWS Payload](#jws-payload)
    + [JWS Signature](#jws-signature)
  * [JWS Compact Serialization](#jws-compact-serialization)
- [JWK Set (JWKS)](#jwk-set-jwks)
  * [JWK Parameters](#jwk-parameters)
  * [Distribution](#distribution)
  * [Examples](#examples)
- [Privacy-Enhanced Mail (PEM) Keys](#privacy-enhanced-mail-pem-keys)
- [Testing OAuth 2.0](#testing-oauth-20)
  * [Client Credentials Flow](#client-credentials-flow)
    + [Script Execution](#script-execution)
    + [Script Internals](#script-internals)
  * [Authorization Code Flow](#authorization-code-flow)
    + [Front-channel Phase](#front-channel-phase)
    + [Back-channel Phase](#back-channel-phase)
      - [Script Execution](#script-execution-1)
      - [Script Internals](#script-internals-1)
        * [Public Clients POST Request](#public-clients-post-request)
        * [Confidential Clients POST Request](#confidential-clients-post-request)
        * [POST Response](#post-response)
  * [Refresh Tokens](#refresh-tokens)
    + [Script Execution](#script-execution-2)
    + [Script Internals](#script-internals-2)
      - [Public Clients POST Request](#public-clients-post-request-1)
      - [Confidential Clients POST Request](#confidential-clients-post-request-1)
      - [POST Response](#post-response-1)
  * [Accessing Protected Resources](#accessing-protected-resources)
    + [Script Execution](#script-execution-3)
    + [Script Internals](#script-internals-3)
- [Cache Strategies](#cache-strategies)
  * [Discovery Document](#discovery-document-1)
  * [Access Tokens](#access-tokens)
  * [Refresh Tokens](#refresh-tokens-1)
  * [Client Credentials Flow](#client-credentials-flow-1)
  * [Authorization Code Flow](#authorization-code-flow-1)

## Client Types

FactSet supports Public and Confidential OAuth 2.0 Clients.

### Public Clients

Public Client applications are incapable of keeping private signing keys confidential. They include Mobile Device Native applications, desktop applications, Single-Page Applications, and IoT devices. Their resources are directly accessible, presenting an opportunity for unauthorized parties to extract embedded data objects, including private signing keys. As such, FactSet stipulates the following.

* Public Clients must use [Authorization Code grant type](https://tools.ietf.org/html/rfc6749#section-4.1), optionally with [Refresh Token](https://tools.ietf.org/html/rfc6749#section-1.5).

* Authorization Code grant type requires the [PKCE](https://tools.ietf.org/html/rfc7636) extension to ensure that the application that initiated the flow is the same as the one which completes it. The [S256 code challenge](https://tools.ietf.org/html/rfc7636#section-4.2) method must be used to protect against disclosure of the code verifier value.

* The redirection URI provided in the Authorization Code request must exactly match one of registered URIs. FactSet's Authorization Server restricts redirection URIs to a fixed set of absolute HTTPS URIs without wildcard domains, paths, or query string components. Since the Authorization Server exclusively delivers the authorization code to an absolute registered URI, the redirection URI provided in the request serves as proof of Client application identity. Refer to [OAuth 2.0 Security Best Current Practice](https://tools.ietf.org/html/draft-ietf-oauth-security-topics-16#section-4.1) for further details.

### Confidential Clients

Confidential Client applications can securely store private signing keys, enabling them to prove identity to FactSet's Authorization Server. FactSet stipulates the following.

* Confidential Clients may use [Client Credentials grant type](https://tools.ietf.org/html/rfc6749#section-4.4) and/or [Authorization Code grant type](https://tools.ietf.org/html/rfc6749#section-4.1), optionally with [Refresh Token](https://tools.ietf.org/html/rfc6749#section-1.5).
  
* Authorization Code grant type requires the [PKCE](https://tools.ietf.org/html/rfc7636) extension to ensure that the application that initiated the flow is the same as the one which completes it. The S256 code challenge method must be used to protect against disclosure of the code verifier value.

* Confidential Clients prove identity with [JSON Web Signature (JWS)](https://tools.ietf.org/html/rfc7515#section-3), a.k.a. signed [JSON Web Token (JWT)](https://tools.ietf.org/html/rfc7519#section-5.1). Before a Confidential Client participates in an OAuth 2.0 flow, the public signing keys used to authenticate the signatures of messages sent by the Client must be registered with Authentication Server via the Developer Portal.

* The redirection URI provided in the Authorization Code request must exactly match one of registered URIs. FactSet's Authorization Server restricts redirection URIs to a fixed set of absolute HTTPS URIs without wildcard domains, paths, or query string components. Since the Authorization Server exclusively delivers the authorization code to an absolute registered URI, the redirection URI provided in the request serves as additional proof of Client application identity. Refer to [OAuth 2.0 Security Best Current Practice](https://tools.ietf.org/html/draft-ietf-oauth-security-topics-16#section-4.1) for further details.

## Discovery Document

The OAuth 2.0 URIs for the [Authorization Endpoint](https://tools.ietf.org/html/rfc6749#section-3.1) and the [Token Endpoint](https://tools.ietf.org/html/rfc6749#section-3.2) are obtainable from FactSet’s [OpenID Connect](https://openid.net/connect/) [Discovery Document](https://openid.net/specs/openid-connect-discovery-1_0.html), a JSON document located at a well-known URI that contains [metadata describing the configuration](https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderMetadata) of FactSet’s OpenID provider. The document can be retrieved from:

`https://auth.factset.com/.well-known/openid-configuration`

Below is a segment of FactSet's Discovery Document fetched at the time of this writing. 

```
{
  issuer: "https://auth.factset.com",
  authorization_endpoint: "https://auth.factset.com/as/authorization.oauth2",
  token_endpoint: "https://auth.factset.com/as/token.oauth2",
  revocation_endpoint: "https://auth.factset.com/as/revoke_token.oauth2",
  userinfo_endpoint: "https://auth.factset.com/idp/userinfo.openid",
  introspection_endpoint: "https://auth.factset.com/as/introspect.oauth2",
  jwks_uri: "https://auth.factset.com/pf/JWKS",
  registration_endpoint: "https://auth.factset.com/as/clients.oauth2",
  ping_revoked_sris_endpoint: "https://auth.factset.com/pf-ws/rest/sessionMgmt/revokedSris",
  ping_end_session_endpoint: "https://auth.factset.com/idp/startSLO.ping",
  device_authorization_endpoint: "https://auth.factset.com/as/device_authz.oauth2",
  ...
}
```

The appropriately named `authorization_endpoint` and `token_endpoint` entries contain the Authorization Endpoint and Token Endpoint URIs, respectively.

For Confidential Client applications, the [Audience (aud)](https://tools.ietf.org/html/rfc7519#section-4.1.3) JWS payload claim must be a single-element array containing the URI in the `issuer` entry. 

Although the values in the Discovery Document are tentative, they will rarely if ever change. The document can be safely cached for 30 days. It does not need to be retrieved at the start of each OAuth 2.0 flow.

## JSON Web Signature (JWS)

Confidential Clients authenticate with [JSON Web Signature (JWS)](https://tools.ietf.org/html/rfc7515#section-3), a.k.a. signed [JSON Web Token (JWT)](https://tools.ietf.org/html/rfc7519#section-5.1).

### JWS Components 
 
JWS consists of the following components. 
 
#### JOSE Header

FactSet requires the following JOSE Header parameters.

* [Algorithm (alg)](https://tools.ietf.org/html/rfc7515#section-4.1.1) must be “RS256”, indicating signing with [RSASSA-PKCS1-v1_5](https://tools.ietf.org/html/rfc3447#section-8.2) using [SHA-256](https://tools.ietf.org/html/rfc6234).

* [Key ID (kid)](https://tools.ietf.org/html/rfc7515#section-4.1.4) must correspond to one of the provided or generated public keys stored by FactSet's Authorization Server during Client registration.

* [Type (typ)](https://tools.ietf.org/html/rfc7515#section-4.1.9) is optional. Its recommended value is “JWT”. 

Example JOSE Header:   

```    
{
  "alg": "RS256",
  "kid": "ed5e11169ee24b14ba8923246afb2cd6"  
}  
``` 
    
#### JWS Payload

FactSet requires the following JWS Payload claims.

* [Issuer (iss)](https://tools.ietf.org/html/rfc7519#section-4.1.1) and [Subject (sub)](https://tools.ietf.org/html/rfc7519#section-4.1.2) must both be the Client ID provided during registration.

* [Issued At (iat)](https://tools.ietf.org/html/rfc7519#section-4.1.6) must be the current time in [seconds since the Epoch](https://en.wikipedia.org/wiki/Unix_time). It is a number, not a string.

* [Expiration Time (exp)](https://tools.ietf.org/html/rfc7519#section-4.1.4) must be the current time plus 5 minutes in [seconds since the Epoch](https://en.wikipedia.org/wiki/Unix_time). It is the latest time the JWS can be used to prove Client identity to the Authentication Server. The value does not correspond to the expiration time of the returned Access Token. This payload claim is a number, not a string.

* [Not Before (nbf)](https://tools.ietf.org/html/rfc7519#section-4.1.5) must be the current time minus 5 seconds in [seconds since the Epoch](https://en.wikipedia.org/wiki/Unix_time). The Authentication Server will not accept the JWS before this time. A value indicating the past should ensure acceptance and 5 seconds is a margin for clock skew. This payload claim is a number, not a string.

* [Audience (aud)](https://tools.ietf.org/html/rfc7519#section-4.1.3) must be a single-element array containing the URI in the `issuer` entry of FactSet's OpenID Connect Discovery Document.  

* [JWT ID (jti)](https://tools.ietf.org/html/rfc7519#section-4.1.7) must be unique for replay prevention. A randomly generated string produced at runtime with at least 256 bits of entropy (43 characters when Base64 encoded) is recommended.

Example JWS Payload:

```
{
  "iss": "9ac38f9be2b24931bb74ba355d07c445",
  "sub": "9ac38f9be2b24931bb74ba355d07c445",
  "iat": 1598994498,            
  "exp": 1598994798,
  "nbf": 1598994493,      
  "aud": [ "https://auth.factset.com" ],
  "jti": "3KqivzXvFyCYOaf5nGSuSOP0Rk2PKHKMCBFiyoxMnZY"
}
```

#### JWS Signature

FactSet requires [RSASSA-PKCS1-v1_5](https://tools.ietf.org/html/rfc3447#section-8.2) using [SHA-256](https://tools.ietf.org/html/rfc6234), a.k.a. RS256.

### JWS Compact Serialization

A Confidential Client transmits a JWS in [Compact Serialized form](https://tools.ietf.org/html/rfc7515#section-3.1), a period-delimited concatenation of [base64url-encodings](https://tools.ietf.org/html/rfc4648#section-5) of the JWS components. For the OAuth 2.0 flows, it is sent in a POST request body parameter.

Example JWS in Compact Serialized form:

```
eyJ98f8GQ789Km0LI35U63naTHiEvBoHXXTIIEHwFImxcphYY1PkKl7tMH7zPUI9jXbNJM8YPagLc5bLPjDfNvebN6.eyJ1KZXXtPVYctFFPLy1Dyyi2OjfSvScGkPwW6neJVbWxJz53YDMb8aAB4Wgany3jFrk4j4D_66SgHPxUlgDDp88scrrtjsO7WugTHsfKrGP383mzQeHw2_SQe9AAQprdRNXnwYTpPAjN9565uHIg3qxrf7tiLGK1uS5yG1KPXQ.TWeHvCfylOIYE-yF8huVj6IdlD8e1fnMENWxiK13gFuKJT8AchPMOxHpPC5jEUGOHgkG7EboBn6tBQOKzWSFZWWoa7XXJBvWRCTks3tJFBB2CG9felNSxvyh4VmHWktKAgDqnJ3zYLiTC4FjK3jiOqeUb1E5PUdCL0zR5fDuk0XibH0yfQpIEVC1HfWCKjF81ATYxQOi6vpLaAyWnX6o8VIVEfqwkLaecel6ZJZ3aAP4zPM_68MPu5HEkka0sqg9CugfVzEuhI699g4L3GRC9iBnTPPRJI1fG4_yUu1cXCE7haQnd6ywGi8jNFQlTEqyOkSkdzNK-WJpWal6Jfuliy
```     

## JWK Set (JWKS)

Before a Confidential Client participates in an OAuth 2.0 flow, the public signing keys used to verify the identity of the Client must be registered with FactSet’s Authentication Server via the Developer Portal. The Developer Portal only accepts signing keys in [JWK Set (JWKS)](https://tools.ietf.org/html/rfc7517#section-5) format, a JSON document containing an array of [JSON Web Key (JWK)](https://tools.ietf.org/html/rfc7517) objects. If a provided JWKS contains public-private key-pairs, the Developer Portal will transform the key-pairs into public keys prior to storage. If a JWKS is not provided, the Developer Portal will generate and return a JWKS containing a single public-private key-pair; and it will store only the generated public key.

### JWK Parameters

FactSet requires the following JWK parameters.

* [Key Type (kty)](https://tools.ietf.org/html/rfc7517#section-4.1) must be “RSA” and  [Algorithm (alg)](https://tools.ietf.org/html/rfc7517#section-4.4) must be “RS256”. This is required for [RSASSA-PKCS1-v1_5](https://tools.ietf.org/html/rfc3447#section-8.2) using [SHA-256](https://tools.ietf.org/html/rfc6234) signing.

* [Public Key Use (use)](https://tools.ietf.org/html/rfc7517#section-4.2) must be “sig” to indicate that the JWK is for verifying and/or generating digital signatures.

* [Key ID (kid)](https://tools.ietf.org/html/rfc7517#section-4.5) must be unique within the JWKS. A JWS sent by the Client will contain a ```kid``` parameter that corresponds to the Key ID of one of the registered public keys. If the specified public key is not found, then the JWS signature cannot be verified and the request will be rejected.

* Modulus and Exponent ([n and e](https://www.iana.org/assignments/jose/jose.xhtml#web-key-parameters), respectively) are required for public keys.

* Modulus, Exponent, Private Exponent, First Prime Factor, Second Prime Factor, First Factor CRT Exponent, Second Factor CRT Exponent, and First CRT Coefficient ([n, e, d, p, q, dp, dq, and qi](https://www.iana.org/assignments/jose/jose.xhtml#web-key-parameters), respectively) are required for public-private key-pairs. The Developer Portal converts public-private key-pairs into public keys by removing all parameters except for Modulus and Exponent (n and e, respectively).
    
### Distribution

Public-private key-pairs are capable of generating and verifying digital signatures. Whereas, public keys are limited to verifying digital signatures. Consequentially, public-private key-pairs must be kept confidential. But public keys may be freely distributed to enable recipients of signed messages to validate the identity of the sender.

### Examples

When registering a Confidential Client, if a JWKS is not provided, the Developer Portal will generate and return a JWKS containing a single public-private key-pair resembling the following.

```
{
  "keys": [
    {
      "kty": "RSA",      
      "alg": "RS256",
      "use": "sig", 
      "kid": "ed5e11169ee24b14ba8923246afb2cd6",      
      "n": "oO2Re_MzrCqR-1rLFcmuZqf2kYmqjWQax1gYo-cWIGEDX_UIvQ4FtDRx53fPfbl_LUhwMPvYhwyy1THndatW1cwJV...",
      "e": "AQAB",
      "d": "KOT2CXd99AxFWIhz_y9nIDMil01Sh-eeXnXmnRAGMWg1wVa1R8WecXK6V0W89ogC53D3AZueJIN3lnG-DcrioCXfY...",
      "p": "8oR_A9NW0NlRw5FXvuGXJNqe9iGZCzl4CGBvE7EekXai8H3FDUh33tG8hyWLaYjcYmd080wPkhbdY3F2TbRdGl3Wg...",
      "q": "qd_kPP2HRMXJX4Wb2DC5QTrAJIGISV4SeId2-w5ZiL37Qgmr-vkax1hr6C5WmnDZOUQ4Jan6endjjl69F1GdnlOjP...",
      "dp": "0-VszTzlCAo55LSjhEa7txnF9qyYejQ2aqtHol8JpHOSHqrld5uwEOIU5ciqLQXF-b0HdGUq3axYt8C1a2OCTb1b...",
      "dq": "P0uH_F2u4CYeETR0TApjjHV6kF-fS0787OH0qDjBjZzUGNgHt5zHqI0-r6VMaYEwvxC3Jvl9tdH0S2DrbdvgMdUS...",
      "qi": "xkZDjufkne-IKamDLXjxp1CnguiZg8oSky-CXDL2WR2IEG0QEASqz-syTsJ3oE0PvdV34q01obM3WpTYocqjAi8T..."
    }
  ]
}
``` 

A JWKS can contain multiple keys. Below is an example containing 2 public-private key-pairs. Note that each key-pair has a unique ```kid``` property.   
    
```
{
  "keys": [
    {
      "kty": "RSA",      
      "alg": "RS256",
      "use": "sig", 
      "kid": "ed5e11169ee24b14ba8923246afb2cd6",      
      "n": "oO2Re_MzrCqR-1rLFcmuZqf2kYmqjWQax1gYo-cWIGEDX_UIvQ4FtDRx53fPfbl_LUhwMPvYhwyy1THndatW1cwJV...",
      "e": "AQAB",
      "d": "KOT2CXd99AxFWIhz_y9nIDMil01Sh-eeXnXmnRAGMWg1wVa1R8WecXK6V0W89ogC53D3AZueJIN3lnG-DcrioCXfY...",
      "p": "8oR_A9NW0NlRw5FXvuGXJNqe9iGZCzl4CGBvE7EekXai8H3FDUh33tG8hyWLaYjcYmd080wPkhbdY3F2TbRdGl3Wg...",
      "q": "qd_kPP2HRMXJX4Wb2DC5QTrAJIGISV4SeId2-w5ZiL37Qgmr-vkax1hr6C5WmnDZOUQ4Jan6endjjl69F1GdnlOjP...",
      "dp": "0-VszTzlCAo55LSjhEa7txnF9qyYejQ2aqtHol8JpHOSHqrld5uwEOIU5ciqLQXF-b0HdGUq3axYt8C1a2OCTb1b...",
      "dq": "P0uH_F2u4CYeETR0TApjjHV6kF-fS0787OH0qDjBjZzUGNgHt5zHqI0-r6VMaYEwvxC3Jvl9tdH0S2DrbdvgMdUS...",
      "qi": "xkZDjufkne-IKamDLXjxp1CnguiZg8oSky-CXDL2WR2IEG0QEASqz-syTsJ3oE0PvdV34q01obM3WpTYocqjAi8T..."
    },
    {
      "kty": "RSA",      
      "alg": "RS256",
      "use": "sig", 
      "kid": "7b1f369480e644749f5d81ae7a18be72",      
      "n": "fu4dtNtqJKr9JlPCyRGf-2HK4xLo-J-2VG07w6gdmw2b5XQQoO2Re_MzrCqR-3rLFmmuZqy2xYmqjWtax1gYo-cWI...",
      "e": "BRDZ",
      "d": "u6lbHbR1t2urnVJ5xkoSjFrS5ZDGwSpbPb46cuz4jM2NVZ02obZcNHTxYAzuhVSkH7lTobmo_1Gi9qDyI9KOOnsRa...",
      "p": "rfBeVNu2HSuB53qKbWKpdmIaDzMpXHR9UrmiN0Nkmv5pDhkw8oR_A9NW0NlRw5FXvuGXJNqe9iGZCzl4CGBvE7Eek...",
      "q": "EslsxVUHwddDJ8PhHyYwCZ9fC49LYImiFuv7D3YwGm3cKkdKRVv223VZXE_b2zDVFzsEmGM-yVPe39kIQii2gq8wz...",
      "dp": "CTb1b5qtxZTXbtOxSUkDPgpUoCVRSvw-tMG9bBNPy_deVXIZGGRCyuw1NLLk9du6-8s8hQVUe7nvBABVcHeQgUaE...",
      "dq": "gMdUSFuxDBe58PO2L1HYlSuFHZGPc1bk0AVSpN38CjjEeV3q1b5d0ilHBOxn1ILPda710ix-uWeU3BPI2uSwECkc...",
      "qi": "Ai8TLvF1Q2mD3EDvORRhY7Pq9y6FYtUa0KP-VxfPGO4F44a0znZddJzZIR3XAI1kPsx0Rz05F1wMvwaLwz4x5ycx..."
    }
  ]
}
```

The public-private key-pairs above were transformed into the public keys below by deleting the private key components. 

```
{
  "keys": [
    {
      "kty": "RSA",      
      "alg": "RS256",
      "use": "sig", 
      "kid": "ed5e11169ee24b14ba8923246afb2cd6",      
      "n": "oO2Re_MzrCqR-1rLFcmuZqf2kYmqjWQax1gYo-cWIGEDX_UIvQ4FtDRx53fPfbl_LUhwMPvYhwyy1THndatW1cwJV...",
      "e": "AQAB",
    },
    {
      "kty": "RSA",      
      "alg": "RS256",
      "use": "sig", 
      "kid": "7b1f369480e644749f5d81ae7a18be72",      
      "n": "fu4dtNtqJKr9JlPCyRGf-2HK4xLo-J-2VG07w6gdmw2b5XQQoO2Re_MzrCqR-3rLFmmuZqy2xYmqjWtax1gYo-cWI...",
      "e": "BRDZ",
    }
  ]
}
```

## Privacy-Enhanced Mail (PEM) Keys

[Privacy-Enhanced Mail (PEM)](https://en.wikipedia.org/wiki/Privacy-Enhanced_Mail) is an alternative format for storing a digital signing key. Although there is no analogue to JWKS (no PEM Set format), freely available utilities exist that can convert between JWK and PEM, with one caveat: PEM does not contain a Key ID. When converting from PEM to JWK, a Key ID must be provided.

To illustrate, below is a JWKS containing 2 public-private key-pairs.

```
{
  "keys": [
    {
      "kty": "RSA",      
      "alg": "RS256",
      "use": "sig", 
      "kid": "ed5e11169ee24b14ba8923246afb2cd6",      
      "n": "oO2Re_MzrCqR-1rLFcmuZqf2kYmqjWQax1gYo-cWIGEDX_UIvQ4FtDRx53fPfbl_LUhwMPvYhwyy1THndatW1cwJV...",
      "e": "AQAB",
      "d": "KOT2CXd99AxFWIhz_y9nIDMil01Sh-eeXnXmnRAGMWg1wVa1R8WecXK6V0W89ogC53D3AZueJIN3lnG-DcrioCXfY...",
      "p": "8oR_A9NW0NlRw5FXvuGXJNqe9iGZCzl4CGBvE7EekXai8H3FDUh33tG8hyWLaYjcYmd080wPkhbdY3F2TbRdGl3Wg...",
      "q": "qd_kPP2HRMXJX4Wb2DC5QTrAJIGISV4SeId2-w5ZiL37Qgmr-vkax1hr6C5WmnDZOUQ4Jan6endjjl69F1GdnlOjP...",
      "dp": "0-VszTzlCAo55LSjhEa7txnF9qyYejQ2aqtHol8JpHOSHqrld5uwEOIU5ciqLQXF-b0HdGUq3axYt8C1a2OCTb1b...",
      "dq": "P0uH_F2u4CYeETR0TApjjHV6kF-fS0787OH0qDjBjZzUGNgHt5zHqI0-r6VMaYEwvxC3Jvl9tdH0S2DrbdvgMdUS...",
      "qi": "xkZDjufkne-IKamDLXjxp1CnguiZg8oSky-CXDL2WR2IEG0QEASqz-syTsJ3oE0PvdV34q01obM3WpTYocqjAi8T..."
    },
    {
      "kty": "RSA",      
      "alg": "RS256",
      "use": "sig", 
      "kid": "7b1f369480e644749f5d81ae7a18be72",      
      "n": "fu4dtNtqJKr9JlPCyRGf-2HK4xLo-J-2VG07w6gdmw2b5XQQoO2Re_MzrCqR-3rLFmmuZqy2xYmqjWtax1gYo-cWI...",
      "e": "BRDZ",
      "d": "u6lbHbR1t2urnVJ5xkoSjFrS5ZDGwSpbPb46cuz4jM2NVZ02obZcNHTxYAzuhVSkH7lTobmo_1Gi9qDyI9KOOnsRa...",
      "p": "rfBeVNu2HSuB53qKbWKpdmIaDzMpXHR9UrmiN0Nkmv5pDhkw8oR_A9NW0NlRw5FXvuGXJNqe9iGZCzl4CGBvE7Eek...",
      "q": "EslsxVUHwddDJ8PhHyYwCZ9fC49LYImiFuv7D3YwGm3cKkdKRVv223VZXE_b2zDVFzsEmGM-yVPe39kIQii2gq8wz...",
      "dp": "CTb1b5qtxZTXbtOxSUkDPgpUoCVRSvw-tMG9bBNPy_deVXIZGGRCyuw1NLLk9du6-8s8hQVUe7nvBABVcHeQgUaE...",
      "dq": "gMdUSFuxDBe58PO2L1HYlSuFHZGPc1bk0AVSpN38CjjEeV3q1b5d0ilHBOxn1ILPda710ix-uWeU3BPI2uSwECkc...",
      "qi": "Ai8TLvF1Q2mD3EDvORRhY7Pq9y6FYtUa0KP-VxfPGO4F44a0znZddJzZIR3XAI1kPsx0Rz05F1wMvwaLwz4x5ycx..."
    }
  ]
}
```

An individual JWK is extracted from the ```keys``` array:  

```
{
  "kty": "RSA",      
  "alg": "RS256",
  "use": "sig", 
  "kid": "ed5e11169ee24b14ba8923246afb2cd6",      
  "n": "oO2Re_MzrCqR-1rLFcmuZqf2kYmqjWQax1gYo-cWIGEDX_UIvQ4FtDRx53fPfbl_LUhwMPvYhwyy1THndatW1cwJV...",
  "e": "AQAB",
  "d": "KOT2CXd99AxFWIhz_y9nIDMil01Sh-eeXnXmnRAGMWg1wVa1R8WecXK6V0W89ogC53D3AZueJIN3lnG-DcrioCXfY...",
  "p": "8oR_A9NW0NlRw5FXvuGXJNqe9iGZCzl4CGBvE7EekXai8H3FDUh33tG8hyWLaYjcYmd080wPkhbdY3F2TbRdGl3Wg...",
  "q": "qd_kPP2HRMXJX4Wb2DC5QTrAJIGISV4SeId2-w5ZiL37Qgmr-vkax1hr6C5WmnDZOUQ4Jan6endjjl69F1GdnlOjP...",
  "dp": "0-VszTzlCAo55LSjhEa7txnF9qyYejQ2aqtHol8JpHOSHqrld5uwEOIU5ciqLQXF-b0HdGUq3axYt8C1a2OCTb1b...",
  "dq": "P0uH_F2u4CYeETR0TApjjHV6kF-fS0787OH0qDjBjZzUGNgHt5zHqI0-r6VMaYEwvxC3Jvl9tdH0S2DrbdvgMdUS...",
  "qi": "xkZDjufkne-IKamDLXjxp1CnguiZg8oSky-CXDL2WR2IEG0QEASqz-syTsJ3oE0PvdV34q01obM3WpTYocqjAi8T..."
}
```

The Key ID is stored separately because it is not preserved during conversion. In this case, the ```kid``` is ```ed5e11169ee24b14ba8923246afb2cd6```.

Finally, the JWK is passed through any of the JWK-to-PEM converters that are readily available for download. The result appear below. Note, to keep private keys private, avoid online converters.

```
-----BEGIN PRIVATE KEY-----
MIIEvgIB6DANBgkqhkiG9w0BAQEFAASCBKgwgwSkAgEAAoIBAQCg7ZF78zOsKpH7
UGrezE12wRHO6GSo2ZMZ/vUWktr5UYlvs6dWorp7CgHVR/j7niWh0vx5G/8NUfXP
xGhTpW8egwKBgQDT5WzNPOUICjnktKOERru3GcX2rJh6NDZqq0eiXwmkc5IequV3
m7AQ4hTlyKotBcX5vQd0ZSrdrFi3wLVrY4JNvVvmq3FlNdu07FJSQM+ClSgJVFK/
D60wb1sE0/L915VchkYZELK7DU0suT127r7yzyFBVR7ue8EAFVwd5CBRoQKBgD9L
h/xdruAmHhE0dEwKY4x1epBfn0tO/Ozh9Kg4wY2c1BjYB7ecx6iNPq+lTGmBML8Q
tyb5fbXR9Etg623b4DHVEhbsQwXufDzti9R2JUrhR2Rj3NW5NAFUqTd/Ao4xHld6
WssVya5mp/aRiaqNZBrHWBij5xYgYQNf9Qi9DgW0NHHnd899uX8tSHAw+9iHDLLV
Med1q1bVzAlVXZft8GotFY7xgi5TS9+0+1MGRNNG3YaG+Ai3a34WT2/JDvtl9s+k
/uwlkO4l+aN3rVRnEvv6jh7+5X7N3Qyc95TW/aO+/jhfu8Empzt1METYj0ea2w2U
SyWzFVQfB10Mnw+EfJjAJn18Lj0tgiaIW6/sPdjAabdwqR0pFW/bbdVlcT9vbMNU
XOwSYYz7JU97f2QhCKLaCrzDOt8F5U27YdK4HneoptYql2YhoPMylcdH1SuaI3Q2
Sa/mkOGTAgMBAAECggEAKOT2CXd99AxFWIhz/y9nIDMil01Sh+eeXnXmnRAGMWg1
wVa1R8WecXK6V0W89o/C53D3AZueJIN+4nG+DcrioCXfYVANYausb5SA5KJeP1CS
op0TNg6bWfDFVNsG7AVm3yiEkaU7AWg80ALv44P24LOVdL4ZKrBKVBt1iPSsyocu
91HKIFw4c6XzLLGg79Y5FsZCYZ11GayIcu6lbHbR1t2urnVJ5xkoSjFrS5ZDGwSp
bPb46cuz4jM2NVZ02obZcNHTxYAzuhVSkHqlTobmo/1Gi9qDyI9KOOnsRafu4dtN
tqJKr9JlPCyRGf+2HK4xLo+J+2VG07w6gdmw2b5XQQKBgQDyhH8D01bQ2VHDkVe+
4Zck3p72IZkLOXgIYG8TsR6RdqLwfcUNSHfe0byHJYtpiNxiZ3TzTA+SFt1jcXZN
tF0aXdaDIYoRAMzE/wEOwh/vkZqUkjoxBqK3HxYvMBhByL0lXULaALbiqd5xdW/G
1HR+vVS9Q22OgqqsAan7FVXDsQKBgQCp3+Q8/YdExclfhZvYMLlBOsAkgYhJXhJ4
h3b7DlmIvftCCav6+RrHWGvoLlaacNk5RDglqfp6d2OOXr0XUZ2eU6M9nbRvmoqG
tW+XdIpRwTsZ9SCz3Wu9dIsfrlnlNwTyNrksBApHAoGBAMZGQ47n5J3viCmpgy14
8adQp4LomYPKEpMvglwy9lkdiBBtEBAEqs/rMk7Cd6BND73Vd+KtNaGzN1qU2KHK
owIvwy7xdUNpg9xA7zkUYWOz6vcuhWLVGtCj/lcXzxjuBeOGtM52XXSc2SEd1wCN
Zm7MdEc9ORdcDL8Gi8M+Mecn
-----END PRIVATE KEY-----
```

Since it represents an RSA key, some converters will produce a PEM with a slightly different header and trailer:

```
-----BEGIN RSA PRIVATE KEY-----
MIIEvgIB6DANBgkqhkiG9w0BAQEFAASCBKgwgwSkAgEAAoIBAQCg7ZF78zOsKpH7
UGrezE12wRHO6GSo2ZMZ/vUWktr5UYlvs6dWorp7CgHVR/j7niWh0vx5G/8NUfXP
xGhTpW8egwKBgQDT5WzNPOUICjnktKOERru3GcX2rJh6NDZqq0eiXwmkc5IequV3
...
Zm7MdEc9ORdcDL8Gi8M+Mecn
-----END RSA PRIVATE KEY-----
```

## Testing OAuth 2.0

This repository contains bash shell scripts for testing the OAuth 2.0 flows. After registering a Client application in the Developer Portal, the scripts can be used to verify that the Client is setup correctly. In addition, if problems are encountered while employing an OAuth 2.0 library, the requests and responses of the scripts can be compared to the those of the library to aid in debugging.

For Confidential Clients, the scripts use [OpenSSL](https://www.openssl.org/) to generate digital signatures. At the time of this writing, OpenSSL does not accept public-private key-pairs in JWKS format. However, it does accept PEM format. See the discussion above for converting JWK to PEM.

The scripts depend on [jq](https://stedolan.github.io/jq/), a command-line JSON processor. If required, download instructions are available [here](https://stedolan.github.io/jq/download/). 

### Client Credentials Flow

[Client Credentials flow](https://tools.ietf.org/html/rfc6749#section-1.3.4) is suitable for machine-to-machine authentication where a specific user’s permission to access data is not required. FactSet restricts the flow to Confidential Clients; i.e., a Client sends an [Access Token](https://tools.ietf.org/html/rfc6749#section-1.4) request directly to the Authorization Server that includes a JWS for Client identity verification.

#### Script Execution

The ```request-token-with-client-creds.sh``` script obtains an Access Token via Client Credentials flow. When executed at the command-line without any arguments, it outputs expected usage:

```
$ ./request-token-with-client-creds.sh

Usage: ./request-token-with-client-creds.sh -option1 arg1 -option2 arg2 ...

Required options:

-c Client ID
-d Discovery Document URI (a.k.a. Well-known URI)
-p PEM file containing an RSA public-private key-pair
-k Signing Key ID

Optional options:

-s Scopes (a space-delimited list surrounded by quotes)
``` 

Below is an example run that uses the following arguments.

* ```a1fd8d65a787416781e31c43306e6bb0``` is the Client ID established when the Client was registered in the Developer Portal.

* ```https://auth.factset.com/.well-known/openid-configuration``` is the Discovery Document URI. The document contains the Token Endpoint URI. Although the script always downloads the document, in production code it can be cached since the endpoint URIs rarely if ever change. 

* ```./pem.txt``` is a file containing a public-private key-pair in PEM format. It is used to generate the signature of the JWS that is sent to the Authorization Server to prove Client identity. See the discussion above for converting JWK to PEM.

* ```ed5e11169ee24b14ba8923246afb2cd6``` is the Key ID (kid) of the JWK that was converted to PEM format.

Example run:

```
$ ./request-token-with-client-creds.sh -c a1fd8d65a787416781e31c43306e6bb0 -d https://auth.factset.com/.well-known/openid-configuration -p ./pem.txt -k ed5e11169ee24b14ba8923246afb2cd6

[access_token]
VjSVmCDiaejIhfTWpugSxXteXtHT

[token_type]
Bearer

[expires_in]
28799
```

The result is an [Access Token](https://tools.ietf.org/html/rfc6749#section-1.4). In this case, it is an opaque [Bearer Token](https://tools.ietf.org/html/rfc6750#section-1.2) that expires in approximately 8 hours. 

The Access Token format and the expiration time are subject to change. A Client application must treat the Access Token as opaque regardless of the actual format. And it must respect the expiration time contained in the response. 

The script optionally accepts a list of [scopes](https://tools.ietf.org/html/rfc6749#section-3.3) to constrain the degree of access granted by an Access Token. Each scope corresponds to a predefined permission type to a dataset, component, functionality, feature, etc. of a specific Protected Resource. FactSet scope names resemble URLs. Below is an example run that uses 3 arbitrarily selected scopes.

```
$ ./request-token-with-client-creds.sh -c a1fd8d65a787416781e31c43306e6bb0 -d https://auth.factset.com/.well-known/openid-configuration -p ./pem.txt -k ed5e11169ee24b14ba8923246afb2cd6 -s "https://api.factset.com/analytics/accounts.fullcontrol https://api.factset.com/analytics/engines.readonly https://api.factset.com/analytics/engines.vault.fullcontrol"

[access_token]
suzzoIyBVtTX5vtVoliErqistX4x

[token_type]
Bearer

[expires_in]
28799
```

#### Script Internals

The script uses cURL to GET the Discovery Document. In production code, the Discovery Document can be cached since the endpoint URIs rarely if ever change.

```
curl -s "https://auth.factset.com/.well-known/openid-configuration"
```

The script pipes the result to ```jq``` to extract the Token Endpoint URI and the issuer. Next, the Client ID, the issuer, the JWK Key ID, and the private-public key-pair in PEM format are collectively used to create a JWS in [Compact Serialized form](https://tools.ietf.org/html/rfc7515#section-3.1) that will enable the Authentication Server to verify the identity of the Client. Finally, the script uses cURL to send the JWS along with any provided scopes in a POST request for the Access Token.

```
curl -s -d "grant_type=client_credentials&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer&client_assertion=eyJ98f8GQ789Km0LI35U63naTHiEvBoHXXTIIEHwFImxcphYY1PkKl7tMH7zPUI9jXbNJM8YPagLc5bLPjDfNvebN6.eyJ1KZXXtPVYctFFPLy1Dyyi2OjfSvScGkPwW6neJVbWxJz53YDMb8aAB4Wgany3jFrk4j4D_66SgHPxUlgDDp88scrrtjsO7WugTHsfKrGP383mzQeHw2_SQe9AAQprdRNXnwYTpPAjN9565uHIg3qxrf7tiLGK1uS5yG1KPXQ.TWeHvCfylOIYE-yF8huVj6IdlD8e1fnMENWxiK13gFuKJT8AchPMOxHpPC5jEUGOHgkG7EboBn6tBQOKzWSFZWWoa7XXJBvWRCTks3tJFBB2CG9felNSxvyh4VmHWktKAgDqnJ3zYLiTC4FjK3jiOqeUb1E5PUdCL0zR5fDuk0XibH0yfQpIEVC1HfWCKjF81ATYxQOi6vpLaAyWnX6o8VIVEfqwkLaecel6ZJZ3aAP4zPM_68MPu5HEkka0sqg9CugfVzEuhI699g4L3GRC9iBnTPPRJI1fG4_yUu1cXCE7haQnd6ywGi8jNFQlTEqyOkSkdzNK-WJpWal6Jfuliy&scope=https%3A%2F%2Fapi.factset.com%2Fanalytics%2Faccounts.fullcontrol%20https%3A%2F%2Fapi.factset.com%2Fanalytics%2Fengines.vault.fullcontrol%20https%3A%2F%2Fapi.factset.com%2Fanalytics%2Flookups.readonly" -X POST "https://auth.factset.com/as/token.oauth2"
```

The HTTP POST will look something like the following.

```
POST /as/token.oauth2 HTTP/2
Host: auth.factset.com
User-Agent: curl/7.58.0
Accept: */*
Content-Length: 1044
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=eyJ98f8GQ789Km0LI35U63naTHiEvBoHXXTIIEHwFImxcphYY1PkKl7tMH7zPUI9jXbNJM8YPagLc5bLPjDfNvebN6.eyJ1KZXXtPVYctFFPLy1Dyyi2OjfSvScGkPwW6neJVbWxJz53YDMb8aAB4Wgany3jFrk4j4D_66SgHPxUlgDDp88scrrtjsO7WugTHsfKrGP383mzQeHw2_SQe9AAQprdRNXnwYTpPAjN9565uHIg3qxrf7tiLGK1uS5yG1KPXQ.TWeHvCfylOIYE-yF8huVj6IdlD8e1fnMENWxiK13gFuKJT8AchPMOxHpPC5jEUGOHgkG7EboBn6tBQOKzWSFZWWoa7XXJBvWRCTks3tJFBB2CG9felNSxvyh4VmHWktKAgDqnJ3zYLiTC4FjK3jiOqeUb1E5PUdCL0zR5fDuk0XibH0yfQpIEVC1HfWCKjF81ATYxQOi6vpLaAyWnX6o8VIVEfqwkLaecel6ZJZ3aAP4zPM_68MPu5HEkka0sqg9CugfVzEuhI699g4L3GRC9iBnTPPRJI1fG4_yUu1cXCE7haQnd6ywGi8jNFQlTEqyOkSkdzNK-WJpWal6Jfuliy
&scope=https%3A%2F%2Fapi.factset.com%2Fanalytics%2Faccounts.fullcontrol%20https%3A%2F%2Fapi.factset.com%2Fanalytics%2Fengines.vault.fullcontrol%20https%3A%2F%2Fapi.factset.com%2Fanalytics%2Flookups.readonly
```

Below is an explanation of each request body query parameter.

* ```grant_type``` is ```client_credentials``` to indicate Client Credentials flow.

* ```client_assertion_type``` is ```urn:ietf:params:oauth:client-assertion-type:jwt-bearer``` to indicate that the Client is authenticating with a JWT Bearer Token.

* ```client_assertion``` is the generated JWS used to authenticate the Client.

* ```scope``` is a [URL encoded](https://en.wikipedia.org/wiki/Percent-encoding) version the requested scopes. 

The response is a JSON document containing an Access Token.

```
{
  "access_token":"qUYZRl9r5bxmPKuMlt4d6OvcQzLE",
  "token_type":"Bearer",
  "expires_in":28799
}
```

The script pipes the response to ```jq``` to pretty-print it.

### Authorization Code Flow

[Authorization Code flow](https://tools.ietf.org/html/rfc6749#section-4.1) is used by web and native Client applications to obtain [Access Tokens](https://tools.ietf.org/html/rfc6749#section-1.4) and [Refresh Tokens](https://tools.ietf.org/html/rfc6749#section-1.5) after a Resource Owner authorizes access to a Protected Resource. The flow is composed of 2 distinct phases: front-channel and back-channel. During the front-channel phase, the Client application communicates indirectly with the Authorization Server by using the Resource Owner’s web browser as a proxy. During the back-channel phase, the Client application communicates directly with the Authorization Server.

#### Front-channel Phase

In the front-channel phase, the Client application directs the Resource Owner’s web browser to FactSet’s Authorization Endpoint. That endpoint enables the Resource Owner to log in to FactSet and to optionally grant the Client application access to specific Protected Resources. Upon completing that process, the Authorization Server issues an [Authorization Code](https://tools.ietf.org/html/rfc6749#section-4.1.2) and it redirects the Resource Owner’s web browser back to the Client application.  

The ```create-auth-code-url.sh``` script outputs an Authorization Code request URL that can be used to initiate an Authorization Code flow. When executed at the command-line without any arguments, it prints expected usage:

```
$ ./create-auth-code-url.sh

Usage: ./create-auth-code-url.sh -option1 arg1 -option2 arg2 ...

Required options:

-c Client ID
-r Redirect URI
-d Discovery Document URI (a.k.a. Well-known URI)

Optional options:

-s Scopes (a space-delimited list surrounded by quotes)
```

Below is an example run that uses the following arguments.

* ```b5381c2dd75942e8a946e09a9bd06e07``` is the Client ID established when the Client was registered in the Developer Portal.

* ```https://example.com/callback``` is one of the redirection URIs registered in the Developer Portal. The Authorization Server will callback this URI after the Resource Owner grants or denies access to the Protected Resource. For this test, nothing needs to be setup to handle the callback.

* ```https://auth.factset.com/.well-known/openid-configuration``` is the Discovery Document URI. The document contains the Authorization Endpoint URI. Although the script always downloads the document, in production code it can be cached since the endpoint URIs rarely if ever change. 

Example run:

```
$ ./create-auth-code-url.sh -c b5381c2dd75942e8a946e09a9bd06e07 -r https://example.com/callback -d https://auth.factset.com/.well-known/openid-configuration

[PKCE Code Verifier]
NW3NxvDc7p1VS87brtYq7t2KpzyCuqLTWbRQ0vhL9jP

[Authorization Code Request URL]
https://auth.factset.com/as/authorization.oauth2?response_type=code&redirect_uri=http%3A%2F%2Fexample.com%2Fcallback&state=pTJxL4HsDzuEisphtqes5KdCJw7SMLzaPeF9ouQf9ka&code_challenge_method=S256&client_id=b5381c2dd75942e8a946e09a9bd06e07&code_challenge=o-Vrb5Jp0XPiZy0h3vs7q0bePXDzrZ_h_Qnmu0z1bZ4
```

In addition to the Authorization Code request URL, the script generates a [Code Verifier](https://tools.ietf.org/html/rfc7636#section-4.1) for [Proof Key for Code Exchange (PKCE)](https://tools.ietf.org/html/rfc7636), an OAuth 2.0 extension that FactSet requires when using Authorization Code flow to mitigate the threat of having the Authorization Code intercepted. The Code Verifier is a randomly generated string. The script passes it through a one-way hash based on [SHA-256](https://tools.ietf.org/html/rfc6234#section-4.1) (S256) to create the [Code Challenge](https://tools.ietf.org/html/rfc7636#section-4.2). The Code Challenge along with the name of the hashing algorithm appear as query parameters in the Authorization Code request. When making the Authorization Code request, the Authorization Server stores these values. And during the subsequent request for the tokens, the Code Verifier is presented along with the Authorization Code. The Authorization Server will reject the tokens request if the hash of the Code Verifier does not match the Code Challenge provided earlier in the Authorization Code request.

To make the query parameters easier to read, a reformatted version of the generated Authorization Code request URL follows.

```
https://auth.factset.com/as/authorization.oauth2
    ?response_type=code
    &redirect_uri=http%3A%2F%2Fexample.com%2Fcallback
    &state=pTJxL4HsDzuEisphtqes5KdCJw7SMLzaPeF9ouQf9ka
    &code_challenge_method=S256
    &client_id=b5381c2dd75942e8a946e09a9bd06e07
    &code_challenge=o-Vrb5Jp0XPiZy0h3vs7q0bePXDzrZ_h_Qnmu0z1bZ4
```

Here is a breakdown of the URL:

* ```https://auth.factset.com/as/authorization.oauth2``` is the Authorization Endpoint. It was obtained from the Discovery Document.

* ```response_type``` is ```code``` to indicate that the ultimate goal of the front-channel request is to obtain an Authorization Code.

* ```redirect_uri``` is [URL encoded](https://en.wikipedia.org/wiki/Percent-encoding), enabling a URL to be passed as a query parameter. 

* ```state``` is a session ID, an arbitrary value used to maintain the session state of the Client application between the Authorization Code request and the callback to the Client. The value is echoed in a query parameter during the callback. Since the script is not a web application, it generates ```state``` for illustrative purposes only. In a production system, ```state``` also safeguards against [cross-site request forgery](https://tools.ietf.org/html/rfc6749#section-10.12).

* ```code_challenge_method``` is the name of the hashing algorithm used to convert the PKCE Code Verifier into the PKCE Code Challenge.

* ```client_id``` is the Client ID established when the Client was registered in the Developer Portal.

* ```code_challenge``` is the hash of the PKCE Code Verifier.

The script optionally accepts a list of [scopes](https://tools.ietf.org/html/rfc6749#section-3.3) to constrain the degree of access granted by an Access Token. Each scope corresponds to a predefined permission type to a dataset, component, functionality, feature, etc. of a specific Protected Resource. FactSet scope names resemble URLs. Below is an example run that uses 3 arbitrarily selected scopes.

```
$ ./create-auth-code-url.sh -c b5381c2dd75942e8a946e09a9bd06e07 -r https://example.com/callback -d https://auth.factset.com/.well-known/openid-configuration -s "https://api.factset.com/analytics/accounts.fullcontrol https://api.factset.com/analytics/engines.readonly https://api.factset.com/analytics/engines.vault.fullcontrol"

[PKCE Code Verifier]
5KOeF0dMrvBpwiu5gY8LvfkYvOmKVMDTF4EDqNhSx2D

[Authorization Code Request URL]
https://auth.factset.com/as/authorization.oauth2?response_type=code&redirect_uri=https%3A%2F%2Fexample.com%2Fcallback&state=MabLeOjYj0clrtNs0XPtUuTxVb869FwPDDYs7Q74Qmh&code_challenge_method=S256&client_id=b5381c2dd75942e8a946e09a9bd06e07&code_challenge=aK5KS4jX3dQMGadmn0xEltBHrELR3HJb7y5h0_K_s50&scope=https%3A%2F%2Fapi.factset.com%2Fanalytics%2Faccounts.fullcontrol%20https%3A%2F%2Fapi.factset.com%2Fanalytics%2Fengines.readonly%20https%3A%2F%2Fapi.factset.com%2Fanalytics%2Fengines.vault.fullcontrol
```

A reformatted version of the generated Authorization Code request URL appears below. 

```
https://auth.factset.com/as/authorization.oauth2    
    ?response_type=code
    &redirect_uri=https%3A%2F%2Fexample.com%2Fcallback
    &state=MabLeOjYj0clrtNs0XPtUuTxVb869FwPDDYs7Q74Qmh
    &code_challenge_method=S256
    &client_id=b5381c2dd75942e8a946e09a9bd06e07
    &code_challenge=aK5KS4jX3dQMGadmn0xEltBHrELR3HJb7y5h0_K_s50
    &scope=https%3A%2F%2Fapi.factset.com%2Fanalytics%2Faccounts.fullcontrol%20https%3A%2F%2Fapi.factset.com%2Fanalytics%2Fengines.readonly%20https%3A%2F%2Fapi.factset.com%2Fanalytics%2Fengines.vault.fullcontrol
```

To initiate an Authorization Code flow, execute ```create-auth-code-url.sh``` and enter the generated Authorization Code request URL into the address bar of a web browser. The Authorization Server will check if the Resource Owner is logged into FactSet. If not, it will respond with the FactSet login page. Once logged in, the Authentication Server will present the consent screen, a web page that explains that the Client application is requesting access to Protected Resources. Buttons on the consent screen enable the Resource Owner to allow or deny access. It also lists the scopes specified in the request URL. The Resource Owner can narrow the list to constrain the degree of access.

Upon pressing the Allow button, the Authorization Server calls back the Client application by using the redirection URI provided in the Authorization Code request. Below is an example callback URL. 

```
https://example.com/callback?code=KTtn33Z-mKfSpqybp-wVipLxMn_SdvOQ72dIpRq3&state=MabLeOjYj0clrtNs0XPtUuTxVb869FwPDDYs7Q74Qmh
```

To make the query parameters easier to read, a reformatted version of the callback URL follows.

```
https://example.com/callback
    ?code=KTtn33Z-mKfSpqybp-wVipLxMn_SdvOQ72dIpRq3
    &state=MabLeOjYj0clrtNs0XPtUuTxVb869FwPDDYs7Q74Qmh
```

Here is an explanation of each part:

* ```https://example.com/callback``` is the ```redirect_uri``` provided in the Authorization Code request. Redirection URIs must be registered with the Authorization Server through the Developer Portal before using Authorization Code flows.

* ```code``` is the issued Authorization Code. In the back-channel phase, the Authorization Code together with the PKCE Code Verifier will be exchanged for an Access Token and possibly a Refresh Token. 

* ```state``` is the ```state``` value provided in the Authorization Code request. It is a session ID, an arbitrary value used to maintain the session state of the Client application between the Authorization Code request and the callback to the Client. 

If the Resource Owner presses the Deny button on the consent screen, the Authorization Server notifies the Client through a callback with different query parameter. An example follows. 

```
https://example.com/callback?error_description=User+Denied+Authorization&state=MabLeOjYj0clrtNs0XPtUuTxVb869FwPDDYs7Q74Qmh&error=access_denied#.
```

A reformatted version of the denied callback appears below.

```
https://example.com/callback
    ?error_description=User+Denied+Authorization
    &state=MabLeOjYj0clrtNs0XPtUuTxVb869FwPDDYs7Q74Qmh
    &error=access_denied
    #.
```

A full list of ```error``` codes is available [here](https://tools.ietf.org/html/rfc6749#section-4.1.2).

#### Back-channel Phase

In the back-channel phase, the Client application communicates directly with the Authorization Server to exchange the Authorization Code along with the PKCE Code Verifier for an Access Token and possibly a Refresh Token. 

##### Script Execution

The ```request-tokens-with-auth-code.sh``` script performs the exchange. When executed at the command-line without any arguments, it prints expected usage:

```
$ ./request-tokens-with-auth-code.sh

Usage: ./request-tokens-with-auth-code.sh -option1 arg1 -option2 arg2 ...

Required options:

-c Client ID
-r Redirect URI
-d Discovery Document URI (a.k.a. Well-known URI)
-o Authorization Code
-v PKCE Code Verifier

For Confidential Clients:

-p PEM file containing an RSA public-private key-pair
-k Signing Key ID
```

```request-tokens-with-auth-code.sh``` works in concert with ```create-auth-code-url.sh```. Below, the ```create-auth-code-url.sh``` script is executed to generate a PKCE Code Verifier and an Authorization Code request URL.

```
$ ./create-auth-code-url.sh -c b5381c2dd75942e8a946e09a9bd06e07 -r https://example.com/callback -d https://auth.factset.com/.well-known/openid-configuration -s "https://api.factset.com/analytics/lookups.spar.readonly https://api.factset.com/analytics/lookups.vault.readonly"

[PKCE Code Verifier]
h3F8ZdWbzsYjhp5VIgBDbNINxwn3MbManK5q3r5Fs0W

[Authorization Code Request URL]
https://auth.factset.com/as/authorization.oauth2?response_type=code&redirect_uri=http%3A%2F%2Fexample.com%2Fcallback&state=Hp6nvinUy9owh0tbwycAZZUB9n30MwjlP7IMviduYWr&code_challenge_method=S256&client_id=b5381c2dd75942e8a946e09a9bd06e07&code_challenge=Q2PTE9StR-AY1YDEmscFIws0fPsxjs4mIjLu961SVDM&scope=https%3A%2F%2Fapi.factset.com%2Fanalytics%2Flookups.spar.readonly%20https%3A%2F%2Fapi.factset.com%2Fanalytics%2Flookups.vault.readonly
```

The Authorization Code request URL is entered into the address bar of a web browser, which brings up the FactSet login page, followed by the consent screen. Pressing the Allow button yields the following callback URL.

```
https://example.com/callback?code=jTSirkmEz_iEcn-qa0Jz6TrIWXF5LgS7PNpMQTpg&state=Hp6nvinUy9owh0tbwycAZZUB9n30MwjlP7IMviduYWr
```

That completes the front-channel phase. 

Below, the ```request-tokens-with-auth-code.sh``` script is executed with the following arguments.

* ```b5381c2dd75942e8a946e09a9bd06e07``` is the Client ID specified in the Authorization Code request.

* ```https://example.com/callback``` is the redirection URI specified in the Authorization Code request.

* ```https://auth.factset.com/.well-known/openid-configuration``` is the Discovery Document URI. The document contains the Token Endpoint URI. Although the script always downloads the document, in production code it can be cached since the endpoint URIs rarely if ever change. 
  
* ```jTSirkmEz_iEcn-qa0Jz6TrIWXF5LgS7PNpMQTpg``` is the Authorization Code returned as a query parameter in the callback URL. It can be copied directly out of the address bar of the web browser.

* ```h3F8ZdWbzsYjhp5VIgBDbNINxwn3MbManK5q3r5Fs0W``` is the PKCE Code Verifier output by the ```create-auth-code-url.sh``` script.

This is a test of a Confidential Client, which required the following additional arguments. 

* ```./pem.txt``` is a file containing a public-private key-pair in PEM format. It is used to generate the signature of the JWS that is sent to the Authorization Server to prove Client identity. See the discussion above for converting JWK to PEM.

* ```ed5e11169ee24b14ba8923246afb2cd6``` is the Key ID (kid) of the JWK that was converted to PEM format.

Example run:

```
$ ./request-tokens-with-auth-code.sh -c b5381c2dd75942e8a946e09a9bd06e07 -r https://example.com/callback -d https://auth.factset.com/.well-known/openid-configuration -o jTSirkmEz_iEcn-qa0Jz6TrIWXF5LgS7PNpMQTpg -v h3F8ZdWbzsYjhp5VIgBDbNINxwn3MbManK5q3r5Fs0W -p ./pem.txt -k ed5e11169ee24b14ba8923246afb2cd6

[access_token]
7svQJUfwYzeDMDkrv8C8QroaLtpM

[refresh_token]
YQCeT84qiH7zPUI9jxbNRM8rPWgY85b1PjDfNwrbN3

[token_type]
Bearer

[expires_in]
28799
```

The result is an [Access Token](https://tools.ietf.org/html/rfc6749#section-1.4) and a [Refresh Token](https://tools.ietf.org/html/rfc6749#section-1.5). In this case, the Access Token is an opaque [Bearer Token](https://tools.ietf.org/html/rfc6750#section-1.2) that expires in approximately 8 hours. 

The Access Token format and the expiration time are subject to change. A Client application must treat the Access Token as opaque regardless of the actual format. And it must respect the expiration time contained in the response.

The response may not include a Refresh Token.

If the Resource Owner narrows the requested scopes on the consent screen, the back-channel response includes a ```scope``` property containing the approved permissions, as demonstrated below.  

```
$ ./request-tokens-with-auth-code.sh -c b5381c2dd75942e8a946e09a9bd06e07 -r https://example.com/callback -d https://auth.factset.com/.well-known/openid-configuration -o UXNcmBpfXUFALHpAk0Lkh9M6Dx4dcWTdJGYqzU8u -v VBNoSgwIE50LlaCCaYHdhvs1rBf5AuK7PUWGOHxELtc -p ./pem.txt -k ed5e11169ee24b14ba8923246afb2cd6

[access_token]
v8XBpZhY3RzZXWuBzOzY29wSpHj4

[refresh_token]
bW03Erc3rIlLtpZCIcLD82Rr1T1uRE2IBWHmEzNfRo

[scope]
https://api.factset.com/analytics/engines.fullcontrol https://api.factset.com/analytics/lookups.spar.readonly

[token_type]
Bearer

[expires_in]
28799
```

If the Resource Owner removes all scopes, the response includes an empty ```scope``` property:

```
$ ./request-tokens-with-auth-code.sh -c b5381c2dd75942e8a946e09a9bd06e07 -r https://example.com/callback -d https://auth.factset.com/.well-known/openid-configuration -o UXNcmBpfXUFALHpAk0Lkh9M6Dx4dcWTdJGYqzU8u -v VBNoSgwIE50LlaCCaYHdhvs1rBf5AuK7PUWGOHxELtc -p ./pem.txt -k ed5e11169ee24b14ba8923246afb2cd6

[access_token]
v8XBpZhY3RzZXWuBzOzY29wSpHj4

[refresh_token]
bW03Erc3rIlLtpZCIcLD82Rr1T1uRE2IBWHmEzNfRo

[scope]


[token_type]
Bearer

[expires_in]
28799
```

```create-auth-code-url.sh``` and ```request-tokens-with-auth-code.sh``` must be run with the proper arguments within a 5-minute window to successfully complete an Authorization Code flow. Missing the window results in an error like the one below.

```
$ ./request-tokens-with-auth-code.sh -c b5381c2dd75942e8a946e09a9bd06e07 -r https://example.com/callback -d https://auth.factset.com/.well-known/openid-configuration -o jTSirkmEz_iEcn-qa0Jz6TrIWXF5LgS7PNpMQTpg -v h3F8ZdWbzsYjhp5VIgBDbNINxwn3MbManK5q3r5Fs0W -p ./pem.txt -k ed5e11169ee24b14ba8923246afb2cd6

[error_description]
Authorization code is invalid or expired.

[error]
invalid_grant
```

A full list of error responses is available [here](https://tools.ietf.org/html/rfc6749#section-5.2).

##### Script Internals

The script uses cURL to GET the Discovery Document. In production code, the Discovery Document can be cached since the endpoint URIs rarely if ever change.

```
curl -s "https://auth.factset.com/.well-known/openid-configuration"
```

The script pipes the result to ```jq``` to extract the Token Endpoint URI and the issuer. 

###### Public Clients POST Request

For Public Clients, the script uses cURL to send a POST request for tokens.

```
curl -s -d "grant_type=authorization_code&redirect_uri=https%3A%2F%2Fexample.com%2Fcallback&code=zWjtH4GZCXXapAyh-w8-t1-Ir_W1wE8kUuxIpRq0&code_verifier=UnhWMp3ZEJv4zGPVkeG2XzLs4kiwQGapLKaKXRKUJt0&client_id=c818c4a2-9fa8-4d8b-9e41-0dad859cbf4a" -X POST "https://auth.factset.com/as/token.oauth2"
```

The HTTP POST will look something like the following.

```
POST /as/token.oauth2 HTTP/2
Host: auth.factset.com
User-Agent: curl/7.58.0
Accept: */*
Content-Length: 574
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&redirect_uri=https%3A%2F%2Fexample.com%2Fcallback
&code=zWjtH4GZCXXapAyh-w8-t1-Ir_W1wE8kUuxIpRq0
&code_verifier=UnhWMp3ZEJv4zGPVkeG2XzLs4kiwQGapLKaKXRKUJt0
&client_id=c818c4a2-9fa8-4d8b-9e41-0dad859cbf4a
```

Below is an explanation of each request body query parameter.

* ```grant_type``` is ```authorization_code``` to indicate a request to exchange an Authorization Code for tokens.

* ```redirect_uri``` is the redirection URI specified in the front-channel phase.

* ```code``` is the Authorization Code returned as a query parameter in the front-channel callback URL.

* ```code_verifier``` is the PKCE Code Verifier output by the ```create-auth-code-url.sh``` script.

* ```client_id``` is the Client ID specified in the front-channel phase.

Public Clients are not authenticated; no assertion is provided in the request.

###### Confidential Clients POST Request

For Confidential Clients, the Client ID, the issuer, the JWK Key ID, and the private-public key-pair in PEM format are collectively used to create a JWS in [Compact Serialized form](https://tools.ietf.org/html/rfc7515#section-3.1) that will enable the Authentication Server to verify the identity of the Client. The script uses cURL to send the JWS in a POST request for tokens.

```
curl -s -d "grant_type=authorization_code&redirect_uri=http%3A%2F%2Fexample.com%2Fcallback&code=pvzJTd9RJWz0E0P5SYySJt4vsQhVqSbMABQqzU8u&code_verifier=RAJN72nzPlHJsjxiu4AMFdub1noCN9SeazI3JwEQRL3&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer&client_assertion=eyJ98f8GQ789Km0LI35U63naTHiEvBoHXXTIIEHwFImxcphYY1PkKl7tMH7zPUI9jXbNJM8YPagLc5bLPjDfNvebN6.eyJ1KZXXtPVYctFFPLy1Dyyi2OjfSvScGkPwW6neJVbWxJz53YDMb8aAB4Wgany3jFrk4j4D_66SgHPxUlgDDp88scrrtjsO7WugTHsfKrGP383mzQeHw2_SQe9AAQprdRNXnwYTpPAjN9565uHIg3qxrf7tiLGK1uS5yG1KPXQ.TWeHvCfylOIYE-yF8huVj6IdlD8e1fnMENWxiK13gFuKJT8AchPMOxHpPC5jEUGOHgkG7EboBn6tBQOKzWSFZWWoa7XXJBvWRCTks3tJFBB2CG9felNSxvyh4VmHWktKAgDqnJ3zYLiTC4FjK3jiOqeUb1E5PUdCL0zR5fDuk0XibH0yfQpIEVC1HfWCKjF81ATYxQOi6vpLaAyWnX6o8VIVEfqwkLaecel6ZJZ3aAP4zPM_68MPu5HEkka0sqg9CugfVzEuhI699g4L3GRC9iBnTPPRJI1fG4_yUu1cXCE7haQnd6ywGi8jNFQlTEqyOkSkdzNK-WJpWal6Jfuliy" -X POST "https://auth.factset.com/as/token.oauth2"
```

The HTTP POST will look something like the following.

```
POST /as/token.oauth2 HTTP/2
Host: auth.factset.com
User-Agent: curl/7.58.0
Accept: */*
Content-Length: 1044
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&redirect_uri=http%3A%2F%2Fexample.com%2Fcallback
&code=pvzJTd9RJWz0E0P5SYySJt4vsQhVqSbMABQqzU8u
&code_verifier=RAJN72nzPlHJsjxiu4AMFdub1noCN9SeazI3JwEQRL3
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=eyJ98f8GQ789Km0LI35U63naTHiEvBoHXXTIIEHwFImxcphYY1PkKl7tMH7zPUI9jXbNJM8YPagLc5bLPjDfNvebN6.eyJ1KZXXtPVYctFFPLy1Dyyi2OjfSvScGkPwW6neJVbWxJz53YDMb8aAB4Wgany3jFrk4j4D_66SgHPxUlgDDp88scrrtjsO7WugTHsfKrGP383mzQeHw2_SQe9AAQprdRNXnwYTpPAjN9565uHIg3qxrf7tiLGK1uS5yG1KPXQ.TWeHvCfylOIYE-yF8huVj6IdlD8e1fnMENWxiK13gFuKJT8AchPMOxHpPC5jEUGOHgkG7EboBn6tBQOKzWSFZWWoa7XXJBvWRCTks3tJFBB2CG9felNSxvyh4VmHWktKAgDqnJ3zYLiTC4FjK3jiOqeUb1E5PUdCL0zR5fDuk0XibH0yfQpIEVC1HfWCKjF81ATYxQOi6vpLaAyWnX6o8VIVEfqwkLaecel6ZJZ3aAP4zPM_68MPu5HEkka0sqg9CugfVzEuhI699g4L3GRC9iBnTPPRJI1fG4_yUu1cXCE7haQnd6ywGi8jNFQlTEqyOkSkdzNK-WJpWal6Jfuliy
```

Below is an explanation of each request body query parameter.

* ```grant_type``` is ```authorization_code``` to indicate a request to exchange an Authorization Code for tokens.

* ```redirect_uri``` is the redirection URI specified in the front-channel phase.

* ```code``` is the Authorization Code returned as a query parameter in the front-channel callback URL.

* ```code_verifier``` is the PKCE Code Verifier output by the ```create-auth-code-url.sh``` script.

* ```client_assertion_type``` is ```urn:ietf:params:oauth:client-assertion-type:jwt-bearer``` to indicate that the Client is authenticating with a JWT Bearer Token.

* ```client_assertion``` is the generated JWS used to authenticate the Client.

###### POST Response

The POST response is a JSON document containing an Access Token and possibly a Refresh Token, depending on how the Client was registered.

```
{
  "access_token":"f8GQ789Km0LI35U63naTHiEvBoHX",
  "refresh_token":"YQCeT84qiH7zPUI9jxbNRM8rPWgY85b1PjDfNwrbN3",
  "token_type":"Bearer",
  "expires_in":28799
}
```

The script pipes the response to ```jq``` to pretty-print it.

### Refresh Tokens

[Refresh Tokens](https://tools.ietf.org/html/rfc6749#section-1.5) are opaque tokens that function as credentials. They enable the Client application to request new Access Tokens directly from the Authorization Server without prompting the Resource Owner to log into FactSet and to grant permissions again. Refresh Tokens are typically used when a cached Access Token expires or otherwise becomes invalid. But they can be used at any time to obtain additional Access Tokens with the same or reduced scope. The process of issuing new Access Tokens does not expire old ones.

#### Script Execution

The ```request-tokens-with-refresh-token.sh``` script obtains a new Access Token from the Authorization Server by presenting a Refresh Token. When executed at the command-line without any arguments, it prints expected usage:

```
$ ./request-tokens-with-refresh-token.sh

Usage: ./request-tokens-with-refresh-token.sh -option1 arg1 -option2 arg2 ...

Required options:

-c Client ID
-r Redirect URI
-d Discovery Document URI (a.k.a. Well-known URI)
-t Refresh Token

For Confidential Clients:

-p PEM file containing an RSA public-private key-pair
-k Signing Key ID

Optional options:

-s Scopes (a space-delimited list surrounded by quotes)
```

```request-tokens-with-refresh-token.sh``` works in concert with ```create-auth-code-url.sh``` and ```request-tokens-with-auth-code.sh```. Below, the ```create-auth-code-url.sh``` script is executed with 3 arbitrarily selected scopes to generate a PKCE Code Verifier and an Authorization Code request URL.

```
$ ./create-auth-code-url.sh -c d2228aeb8e434fcaad9d77309b9bebf5 -r https://example.com/callback -d https://auth.factset.com/.well-known/openid-configuration -s "https://api.factset.com/analytics/lookups.spar.readonly https://api.factset.com/analytics/engines.pub.fullcontrol https://api.factset.com/analytics/lookups.vault.readonly"

[PKCE Code Verifier]
Msvp2UQGOwN2hTE3iFR9Ul479jssKk1lFsSAz0P5ZdS

[Authorization Code Request URL]
https://auth.factset.com/as/authorization.oauth2&response_type=code&redirect_uri=https%3A%2F%2Fexample.com%2Fcallback&state=fNkV9OHtj0oylwsEZ9RYbngAxwHgEe0Q3djTDEwOHDx&code_challenge_method=S256&client_id=d2228aeb8e434fcaad9d77309b9bebf5&code_challenge=rL6rrQPjLNTvvkbQEa94PNVIFMpxz8WNfthtaO8RSm0&scope=https%3A%2F%2Fapi.factset.com%2Fanalytics%2Flookups.spar.readonly%20https%3A%2F%2Fapi.factset.com%2Fanalytics%2Fengines.pub.fullcontrol%20https%3A%2F%2Fapi.factset.com%2Fanalytics%2Flookups.vault.readonly
```

The Authorization Code request URL is entered into the address bar of a web browser, which brings up the FactSet login page, followed by the consent screen. Pressing the Allow button yields the following callback URL.

```
https://example.com/callback?code=gCjbfsbc9x7glnFUTyVb4wnZZXxrESnaFOEqzU8u&state=fNkV9OHtj0oylwsEZ9RYbngAxwHgEe0Q3djTDEwOHDx
```

That completes the front-channel phase of an Authorization Code flow. Below, the ```request-tokens-with-auth-code.sh``` script is employed to carry out the back-channel phase. The PEM filename and Key ID arguments indicate that this is a test for a Confidential Client.    

```
$ ./request-tokens-with-auth-code.sh -c d2228aeb8e434fcaad9d77309b9bebf5 -r https://example.com/callback -d https://auth.factset.com/.well-known/openid-configuration -o gCjbfsbc9x7glnFUTyVb4wnZZXxrESnaFOEqzU8u -v Msvp2UQGOwN2hTE3iFR9Ul479jssKk1lFsSAz0P5ZdS -p ./pem.txt -k ed5e11169ee24b14ba8923246afb2cd6

[access_token]
dl94d6OvcQzLEqUYZR5qxmPKuMlt

[refresh_token]
r3cd5czUdE8szHxXLICTmXBfqtHKQUsyMw6Rtp3ai

[token_type]
Bearer

[expires_in]
28799
```

The back-channel phase obtains an Access Token and a Refresh Token. Note, depending on how the Client was registered with the Developer Portal, Authorization Code flow may not provide a Refresh Token.

Below, the ```request-tokens-with-refresh-token.sh``` script is executed with the following arguments.

* ```d2228aeb8e434fcaad9d77309b9bebf5``` is the Client ID used in the Authorization Code flow.

* ```https://example.com/callback``` is the redirection URI used in the Authorization Code flow.

* ```https://auth.factset.com/.well-known/openid-configuration``` is the Discovery Document URI. The document contains the Token Endpoint URI. Although the script always downloads the document, in production code it can be cached since the endpoint URIs rarely if ever change.

* ```r3cd5czUdE8szHxXLICTmXBfqtHKQUsyMw6Rtp3ai``` is the Refresh Token output by the ```request-tokens-with-auth-code.sh``` script during the Authorization Code flow back-channel phase.

This is a test of a Confidential Client, which required the following additional arguments.

* ```./pem.txt``` is a file containing a public-private key-pair in PEM format. It is used to generate the signature of the JWS that is sent to the Authorization Server to prove Client identity. See the discussion above for converting JWK to PEM.

* ```ed5e11169ee24b14ba8923246afb2cd6``` is the Key ID (kid) of the JWK that was converted to PEM format.

Example run:

```
$ ./request-tokens-with-refresh-token.sh -c d2228aeb8e434fcaad9d77309b9bebf5 -r https://example.com/callback -d https://auth.factset.com/.well-known/openid-configuration -t r3cd5czUdE8szHxXLICTmXBfqtHKQUsyMw6Rtp3ai -p ./pem.txt -k ed5e11169ee24b14ba8923246afb2cd6

[access_token]
rif6giVTkMDplgMV8w5eUXyup1zU

[token_type]
Bearer

[expires_in]
28799
```

The result is a new [Access Token](https://tools.ietf.org/html/rfc6749#section-1.4). In this case, it is an opaque [Bearer Token](https://tools.ietf.org/html/rfc6750#section-1.2) that expires in approximately 8 hours.

The Access Token format and the expiration time are subject to change. A Client application must treat the Access Token as opaque regardless of the actual format. And it must respect the expiration time contained in the response.

If the Refresh Token is more than 24 hours old, using it will return a new Access Token plus a new Refresh Token, as demonstrated below. 

```
$ ./request-tokens-with-refresh-token.sh -c d2228aeb8e434fcaad9d77309b9bebf5 -r https://example.com/callback -d https://auth.factset.com/.well-known/openid-configuration -t r3cd5czUdE8szHxXLICTmXBfqtHKQUsyMw6Rtp3ai -p ./pem.txt -k ed5e11169ee24b14ba8923246afb2cd6

[access_token]
WJ5qgyUiIwBhjC9iHBmfU3tDLW29

[refresh_token]
uk0XibHWOi6vp0yfQXfW5KjF81ATYxpIEvC3LaAyk

[token_type]
Bearer

[expires_in]
28799
```

Issuing a new Refresh Token expires the old one. The following examples proves this by attempting to use the original. 

```
$ ./request-tokens-with-refresh-token.sh -c d2228aeb8e434fcaad9d77309b9bebf5 -r https://example.com/callback -d https://auth.factset.com/.well-known/openid-configuration -t r3cd5czUdE8szHxXLICTmXBfqtHKQUsyMw6Rtp3ai -p ./pem.txt -k ed5e11169ee24b14ba8923246afb2cd6

[error_description]
unknown, invalid, or expired refresh token

[error]
invalid_grant
```

Other events can result in a similar error message:

* The Resource Owner can rescind permissions granted to a Client at any time.

* Refresh Tokens automatically expire after 30 days of disuse.

* Refresh Tokens may be exchanged for new Access Tokens and new Refresh Tokens for up to a year. After that, the Client must initiate an Authorization Code flow, prompting the Resource Owner to log into FactSet and to grant permissions again.

* The Authorization Server indexes Refresh Tokens using the triplet (Client ID, Resource Owner ID, granted permissions) as the key. If an Authorization Code flow is repeated for the same triplet, the existing Refresh Token will be invalidated.

When presenting a Refresh Token, if no scopes are specified, the new Access Token will bear the same permissions as the one issued during the Authorization Code flow. However, as shown below, scopes can be provided in the request to diminish the granted permissions. In this case, the list has been narrowed to a single scope.

```
$ ./request-tokens-with-refresh-token.sh -c d2228aeb8e434fcaad9d77309b9bebf5 -r https://example.com/callback -d https://auth.factset.com/.well-known/openid-configuration -t uk0XibHWOi6vp0yfQXfW5KjF81ATYxpIEvC3LaAyk -p ./pem.txt -k ed5e11169ee24b14ba8923246afb2cd6 -s "https://api.factset.com/analytics/lookups.spar.readonly"

[access_token]
ou0ChNEgmfgBHGsb2dL4sodT9plC

[token_type]
Bearer

[expires_in]
28799
```

To remove all scopes, set the list to a single space:

```
$ ./request-tokens-with-refresh-token.sh -c d2228aeb8e434fcaad9d77309b9bebf5 -r https://example.com/callback -d https://auth.factset.com/.well-known/openid-configuration -t uk0XibHWOi6vp0yfQXfW5KjF81ATYxpIEvC3LaAyk -p ./pem.txt -k ed5e11169ee24b14ba8923246afb2cd6 -s " "

[access_token]
ou0ChNEgmfgBHGsb2dL4sodT9plC

[token_type]
Bearer

[expires_in]
28799
```

In the following example, an attempt is made to widen the scopes list.

```
$ ./request-tokens-with-refresh-token.sh -c d2228aeb8e434fcaad9d77309b9bebf5 -r https://example.com/callback -d https://auth.factset.com/.well-known/openid-configuration -t uk0XibHWOi6vp0yfQXfW5KjF81ATYxpIEvC3LaAyk -p ./pem.txt -k ed5e11169ee24b14ba8923246afb2cd6 -s "https://api.factset.com/analytics/accounts.fullcontrol https://api.factset.com/analytics/engines.fullcontrol https://api.factset.com/analytics/engines.vault.fullcontrol https://api.factset.com/analytics/lookups.spar.readonly"

[error]
invalid_scope
```

#### Script Internals

The script uses cURL to GET the Discovery Document. In production code, the Discovery Document can be cached since the endpoint URIs rarely if ever change.

```
curl -s "https://auth.factset.com/.well-known/openid-configuration"
```

The script pipes the result to ```jq``` to extract the Token Endpoint URI and the issuer.

##### Public Clients POST Request

For Public Clients, the script uses cURL to send a POST request to the Token Endpoint.

```
curl -s -d "grant_type=refresh_token&redirect_uri=https%3A%2F%2Fexample.com%2Fcallback&refresh_token=gt8kJ2L2GLUlWxnFpAO3OJyCtZ3hmWLBgu24mA6wks&client_id=d2228aeb8e434fcaad9d77309b9bebf5" -X POST "https://auth.factset.com/as/token.oauth2"
```

The HTTP POST will look something like the following.

```
POST /as/token.oauth2 HTTP/2
Host: auth.factset.com
User-Agent: curl/7.58.0
Accept: */*
Content-Length: 862
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token
&redirect_uri=https%3A%2F%2Fexample.com%2Fcallback
&refresh_token=gt8kJ2L2GLUlWxnFpAO3OJyCtZ3hmWLBgu24mA6wks
&client_id=d2228aeb8e434fcaad9d77309b9bebf5
```

Below is an explanation of each request body query parameter.

* ```grant_type``` is ```refresh_token``` to indicate a request for a new Access Token by submission of a Refresh Token.

* ```redirect_uri``` is the redirection URI used in the Authorization Code flow.

* ```refresh_token``` is the latest Refresh Token issued to the Client application.

* ```client_id``` is the Client ID used in the Authorization Code flow.

##### Confidential Clients POST Request

For Confidential Clients, the Client ID, the issuer, the JWK Key ID, and the private-public key-pair in PEM format are collectively used to create a JWS in [Compact Serialized form](https://tools.ietf.org/html/rfc7515#section-3.1) that will enable the Authentication Server to verify the identity of the Client. The script uses cURL to send the JWS in a POST request for tokens.

```
curl -s -d "grant_type=refresh_token&redirect_uri=https%3A%2F%2Fexample.com%2Fcallback&refresh_token=ZDMS5K5zUdE8szHxXLICTmXBfzThKQUsyyw6RtpbaC&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer&client_assertion=eyJ98f8GQ789Km0LI35U63naTHiEvBoHXXTIIEHwFImxcphYY1PkKl7tMH7zPUI9jXbNJM8YPagLc5bLPjDfNvebN6.eyJ1KZXXtPVYctFFPLy1Dyyi2OjfSvScGkPwW6neJVbWxJz53YDMb8aAB4Wgany3jFrk4j4D_66SgHPxUlgDDp88scrrtjsO7WugTHsfKrGP383mzQeHw2_SQe9AAQprdRNXnwYTpPAjN9565uHIg3qxrf7tiLGK1uS5yG1KPXQ.TWeHvCfylOIYE-yF8huVj6IdlD8e1fnMENWxiK13gFuKJT8AchPMOxHpPC5jEUGOHgkG7EboBn6tBQOKzWSFZWWoa7XXJBvWRCTks3tJFBB2CG9felNSxvyh4VmHWktKAgDqnJ3zYLiTC4FjK3jiOqeUb1E5PUdCL0zR5fDuk0XibH0yfQpIEVC1HfWCKjF81ATYxQOi6vpLaAyWnX6o8VIVEfqwkLaecel6ZJZ3aAP4zPM_68MPu5HEkka0sqg9CugfVzEuhI699g4L3GRC9iBnTPPRJI1fG4_yUu1cXCE7haQnd6ywGi8jNFQlTEqyOkSkdzNK-WJpWal6Jfuliy"  -X POST "https://auth.factset.com/as/token.oauth2"
```

The HTTP POST will look something like the following.

```
POST /as/token.oauth2 HTTP/2
Host: auth.factset.com
User-Agent: curl/7.58.0
Accept: */*
Content-Length: 1044
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token
&redirect_uri=https%3A%2F%2Fexample.com%2Fcallback
&refresh_token=ZDMS5K5zUdE8szHxXLICTmXBfzThKQUsyyw6RtpbaC
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=eyJ98f8GQ789Km0LI35U63naTHiEvBoHXXTIIEHwFImxcphYY1PkKl7tMH7zPUI9jXbNJM8YPagLc5bLPjDfNvebN6.eyJ1KZXXtPVYctFFPLy1Dyyi2OjfSvScGkPwW6neJVbWxJz53YDMb8aAB4Wgany3jFrk4j4D_66SgHPxUlgDDp88scrrtjsO7WugTHsfKrGP383mzQeHw2_SQe9AAQprdRNXnwYTpPAjN9565uHIg3qxrf7tiLGK1uS5yG1KPXQ.TWeHvCfylOIYE-yF8huVj6IdlD8e1fnMENWxiK13gFuKJT8AchPMOxHpPC5jEUGOHgkG7EboBn6tBQOKzWSFZWWoa7XXJBvWRCTks3tJFBB2CG9felNSxvyh4VmHWktKAgDqnJ3zYLiTC4FjK3jiOqeUb1E5PUdCL0zR5fDuk0XibH0yfQpIEVC1HfWCKjF81ATYxQOi6vpLaAyWnX6o8VIVEfqwkLaecel6ZJZ3aAP4zPM_68MPu5HEkka0sqg9CugfVzEuhI699g4L3GRC9iBnTPPRJI1fG4_yUu1cXCE7haQnd6ywGi8jNFQlTEqyOkSkdzNK-WJpWal6Jfuliy
```

Below is an explanation of each request body query parameter.

* ```grant_type``` is ```refresh_token``` to indicate a request for a new Access Token by submission of a Refresh Token.

* ```redirect_uri``` is the redirection URI used in the Authorization Code flow.

* ```refresh_token``` is the latest Refresh Token issued to the Client application.

* ```client_assertion_type``` is ```urn:ietf:params:oauth:client-assertion-type:jwt-bearer``` to indicate that the Client is authenticating with a JWT Bearer Token.

* ```client_assertion``` is the generated JWS used to authenticate the Client.

##### POST Response

The POST response is a JSON document containing a newly issued Access Token.

```
{
  "access_token":"cPucQzRlWW5VxmqUYZPizNlLEt5d",
  "token_type":"Bearer",
  "expires_in":28799
}
```

If the submitted Refresh Token is more than 24 hours old, the request will cause it to expire and the response will include a newly issued Refresh Token to replace it.

```
{                  
  "access_token":"PjDfNvebN6cPucQzRlKl7tMH7zPU",
  "refresh_token":"w8eT84qrPWgY85b2PmDrNwrbNMYqCiH7zPUI99xbNR",
  "token_type":"Bearer",
  "expires_in":28799
}
```

### Accessing Protected Resources

OAuth 2.0 defines [multiple ways](https://tools.ietf.org/html/rfc6750#section-2) to send [Access Tokens](https://tools.ietf.org/html/rfc6749#section-1.4) in requests for Protected Resources, but FactSet only supports [the Authorization HTTP request header method](https://tools.ietf.org/html/rfc6750#section-2.1). 

#### Script Execution

The ```access-protected-resource.sh``` script calls a FactSet API endpoint with an Access Token in the authorization header. When executed at the command-line without any arguments, it outputs expected usage:

```
$ ./access-protected-resource.sh

Usage: ./access-protected-resource.sh -option1 arg1 -option2 arg2 ...

Required options:

-a Access Token
-u Protected Resource URL
```

```access-protected-resource.sh``` works in concert with the Client Credentials flow and the Authorization Code flow scripts. In the following example, ```request-token-with-client-creds.sh``` obtains an Access Token via Client Credentials flow. The specified scope narrows access to reading lookups data from the PA Engine API, an API that provides analytics for multi-asset class performance, attribution, and risk.

```
./request-token-with-client-creds.sh -c af00cec026bf470db25031d25abc1a8f -d https://auth.factset.com/.well-known/openid-configuration -p ./pem.txt -k ed5e11169ee24b14ba8923246afb2cd6 -s "https://api.factset.com/analytics/lookups.pa.readonly"

[access_token]
WmYhMqeQqeWrraziCcDEMGFPMHnm

[token_type]
Bearer

[expires_in]
28799
```

Below, the newly issued Access Token is provided as an argument of ```access-protected-resource.sh``` along with the URL of the endpoint that lists all the frequencies that can be applied to a PA calculation. Note that, while FactSet scope names resemble URLs, there is not necessarily a 1-to-1 correspondence between a scope name and a FactSet API endpoint.

```
./access-protected-resource.sh -a WmYhMqeQqeWrraziCcDEMGFPMHnm -u https://api.factset.com/analytics/lookups/v2/engines/pa/frequencies

{
  "Single": {
    "name": "Single"
  },
  "FiscalYearly": {
    "name": "Fiscal Yearly"
  },
  "Annually": {
    "name": "Annually"
  },
  "SemiAnnually": {
    "name": "Semi Annually"
  },
  "Quarterly": {
    "name": "Quarterly"
  },
  "Monthly": {
    "name": "Monthly"
  },
  "Weekly": {
    "name": "Weekly"
  },
  "Daily": {
    "name": "Daily"
  }
}
```

The resultant JSON document indicates successful authorization.

#### Script Internals

The script uses cURL to send the Access Token in the Authorization header of a GET request to the PA Engine API.

```
curl -sk -H "Authorization: Bearer WmYhMqeQqeWrraziCcDEMGFPMHnm" "https://api.factset.com/analytics/lookups/v2/engines/pa/frequencies"
```

The HTTP GET will look something like the following.

```
GET /analytics/lookups/v2/engines/pa/frequencies HTTP/2
Host: api.factset.com
User-Agent: curl/7.58.0
Accept: */*
Authorization: Bearer WmYhMqeQqeWrraziCcDEMGFPMHnm
```

The script pipes the response to ```jq``` to pretty-print it.

If the Access Token expired or it is invalid because the Resource Owner revoked permissions, the Authorization Server will respond with a [401 Unauthorized](https://tools.ietf.org/html/rfc7235#section-3.1):  

```
HTTP/2 401
www-authenticate: FactSet-JWT
content-length: 794
content-type: text/html
```

If the Access Token is corrupted or the request is malformed, the Authorization Server will redirect to the FactSet login page:

```
HTTP/2 302
location: https://login.factset.com/login/login.html?redirect=https%3A%2F%2Fapi.factset.com%2Fanalytics%2Flookups%2Fv2%2Fengines%2Fpa%2Ffrequencies
cache-control: no-cache, no-store
content-length: 0
```

## Cache Strategies

This section discusses strategies to avoid repeating OAuth 2.0 operations unnecessarily.

### Discovery Document

The Discovery Document will rarely if ever change. The document can be safely cached for 30 days. It does not need to be retrieved at the start of each OAuth 2.0 flow.

### Access Tokens

When the Authorization Server issues an Access Token, the response includes the token’s lifetime:

```
./request-token-with-client-creds.sh -c af00cec026bf470db25031d25abc1a8f -d https://auth.factset.com/.well-known/openid-configuration -p ./pem.txt -k ed5e11169ee24b14ba8923246afb2cd6 -s "https://api.factset.com/analytics/lookups.pa.readonly"

[access_token]
WmYhMqeQqeWrraziCcDEMGFPMHnm

[token_type]
Bearer

[expires_in]
28799
```

In this case, the Access Token expires in 28,799 seconds, or approximately 8 hours. It can be reused for that period, providing access to multiple FactSet API endpoints without repeating an OAuth 2.0 flow.

The Resource Owner can rescind permissions granted to a Client at any time. Attempting to access a FactSet API endpoint with an expired Access Token will result in a [401 Unauthorized](https://tools.ietf.org/html/rfc7235#section-3.1).

### Refresh Tokens

The expiration period declared by an Authorization Code flow refers to the Access Token. The response does not include a lifetime for the Refresh Token, as shown below.

```
$ ./request-tokens-with-auth-code.sh -c d2228aeb8e434fcaad9d77309b9bebf5 -r https://example.com/callback -d https://auth.factset.com/.well-known/openid-configuration -o gCjbfsbc9x7glnFUTyVb4wnZZXxrESnaFOEqzU8u -v Msvp2UQGOwN2hTE3iFR9Ul479jssKk1lFsSAz0P5ZdS -p ./pem.txt -k ed5e11169ee24b14ba8923246afb2cd6

[access_token]
dl94d6OvcQzLEqUYZR5qxmPKuMlt

[refresh_token]
r3cd5czUdE8szHxXLICTmXBfqtHKQUsyMw6Rtp3ai

[token_type]
Bearer

[expires_in]
28799
```

Here are some rules governing Refresh Token expiration:

* The Resource Owner can rescind permissions granted to a Client at any time, expiring existing Refresh Tokens.

* Refresh Tokens automatically expire after 30 days of disuse.

* Refresh Tokens may be exchanged for new Access Tokens and new Refresh Tokens for up to a year. After that, the Client must initiate an Authorization Code flow, prompting the Resource Owner to log into FactSet and to grant permissions again.

* The Authorization Server indexes Refresh Tokens using the triplet (Client ID, Resource Owner ID, granted permissions) as the key. If an Authorization Code flow is repeated for the same triplet, the existing Refresh Token will be invalidated.

* To enhance security, Refresh Tokens are cycled. If a Refresh Token is more than 24 hours old, using it to acquire a new Access Token will also provide a new Refresh Token. The process of issuing a new Refresh Token expires the old one.

The only way to determine if a Refresh Token is expired or otherwise invalid is to attempt to use it to obtain a new Access Token. The following example shows a failed attempt.

```
$ ./request-tokens-with-refresh-token.sh -c d2228aeb8e434fcaad9d77309b9bebf5 -r https://example.com/callback -d https://auth.factset.com/.well-known/openid-configuration -t r3cd5czUdE8szHxXLICTmXBfqtHKQUsyMw6Rtp3ai -p ./pem.txt -k ed5e11169ee24b14ba8923246afb2cd6

[error_description]
unknown, invalid, or expired refresh token

[error]
invalid_grant
```

### Client Credentials Flow

A Client application that employs Client Credentials flow is limited to accessing the Protected Resources of a single Resource Owner. The flow does not involve Refresh Tokens. But the flow could be used repeatedly to create Access Tokens of varying scope. Consequentially, a Client Clients flow Client needs to maintain a cache where the key is a scopes set and the value is an Access Token paired with an expiration time:

```
{ scopes set } -> { Access Token, expiration }
```

When the Client needs to access a FactSet API endpoint, it queries the cache for a non-expired Access Token containing the scopes required by the endpoint. 

If no Access Token is found, the Client executes a Client Credentials flow, presenting the required scopes in the request. 

* If the flow succeeds, the newly issued Access Token along with its expiration time is added to the cache.

* If the flow fails, it retries. But, after a certain number of attempts, the Client treats the endpoint as inaccessible. 

The newly-issued or cache-retrieved Access Token is sent in the FactSet API endpoint request. 

* If it responds with a 200 OK, then the Client application successfully accessed the FactSet API endpoint.

* If it responds with a 401 Unauthenticated, then the (presumably cache-retrieved) Access Token is invalid (even if non-expired). 

    * The Access Token is removed from the cache.

    * The entire procedure above is repeated. But, after a certain number of attempts, the Client treats the endpoint as inaccessible.

### Authorization Code Flow

A Client application that employs Authorization Code flow may access the Protected Resources of multiple Resource Owners. The flow could be used repeatedly to create Access Tokens of varying scopes. Consequentially, an Authorization Code flow Client needs to maintain a cache where the key is a Resource Owner ID paired with a scopes set and the value is a triplet containing an Access Token, an expiration time, and a Refresh Token: 

```
{ Resource Owner ID, scopes set } -> { Access Token, expiration, Refresh Token }
```

When a Resource Owner logs in to the Client application, the application either creates a new session or it restores an existing session to maintain user state. The login process captures a Resource Owner ID into the session.

When the Client needs to access a FactSet API endpoint on behalf of a Resource Owner, it queries the cache using the scopes set required by the endpoint.  

If the cache doesn’t contain a non-expired Access Token, but it does have a Refresh Token, then the Client presents the Refresh Token and the required scopes in a request for a new Access Token, directly with the Authorization Sever.
    
* If the request succeeds, the cache is updated with the newly issued Access Token along with its expiration time and, potentially, a newly issued Refresh Token.
  
* If the request fails, then the Refresh Token is invalid. The Client initiates an Authorization Code flow.

    * If the flow succeeds, the cache is updated with the newly issued Access Token, its expiration time, and the newly issued Refresh Token. Critically, the scopes set used in the cache key comes from the Authorization Code flow response, not the scopes set sent in the flow request; the Resource Owner may narrow the requested scopes on the consent screen.
    
    * If the flow fails, the Client treats the endpoint as inaccessible.
    
The newly-issued or cache-retrieved Access Token is sent in the FactSet API endpoint request.

* If it responds with a 200 OK, then the Client application successfully accessed the FactSet API endpoint.

* If it responds with a 401 Unauthenticated, then the (presumably cache-retrieved) Access Token is invalid (even if non-expired). 

    * If a Refresh Token is available, the Client tries the procedure described above for Refresh Tokens, which may result in a second attempt to access the FactSet API endpoint.

    * Otherwise, the Client initiates an Authorization Code flow, following the resultant logic above, which may result in a second attempt to access the FactSet API endpoint.