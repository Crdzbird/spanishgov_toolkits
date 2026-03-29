package es.gob.electronic_dnie.utils

import kotlin.coroutines.CoroutineContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers

class DSCustomIOScope : CoroutineScope {
    override val coroutineContext: CoroutineContext = Dispatchers.IO
}
