package es.gob.electronic_dnie.triphase.adesp_signer.retrofit

import okhttp3.RequestBody
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.Header
import retrofit2.http.POST

interface SignerService {
    @POST("/afirma-server-triphase-signer/SignatureService")
    suspend fun prePostSignData(
        @Header("Content-Type") contentType: String = "text/plain",
        @Body body: RequestBody
    ): Response<ResponseBody>
}