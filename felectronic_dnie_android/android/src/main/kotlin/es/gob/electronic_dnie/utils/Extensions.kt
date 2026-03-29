package es.gob.electronic_dnie.utils

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.withContext

suspend fun <T : Any?> Flow<Result<T>>.observe(
    onSuccess: (T) -> Unit,
    onError: (Throwable) -> Unit
) {
    this.collect { result ->
        result.onSuccess {
            withContext(Dispatchers.Main) {
                onSuccess(it)
            }
        }.onFailure {
            withContext(Dispatchers.Main) {
                onError(it)
            }
        }
    }
}
