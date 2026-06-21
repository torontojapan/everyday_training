package com.goexercise.app.presentation.referral

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.goexercise.app.domain.friends.FriendCode

/** 招待コード入力欄(オンボ・設定で再利用)。入力は自己補正(大文字化・許可文字・6桁)。 */
@Composable
fun InviteCodeField(
    code: String,
    onCodeChange: (String) -> Unit,
    isSubmitting: Boolean,
    onSubmit: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("招待コードをお持ちですか?(任意)", style = MaterialTheme.typography.titleSmall)
        Text("友達のコードを入れると、お互いに保険チケットが増えます。", style = MaterialTheme.typography.bodySmall)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            OutlinedTextField(
                value = code,
                onValueChange = { onCodeChange(FriendCode.sanitize(it)) },
                placeholder = { Text("ABC123") },
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
            Button(onClick = onSubmit, enabled = FriendCode.isValid(code) && !isSubmitting) {
                if (isSubmitting) CircularProgressIndicator(modifier = Modifier.size(18.dp)) else Text("送信")
            }
        }
    }
}
