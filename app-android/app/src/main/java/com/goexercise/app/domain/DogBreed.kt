package com.goexercise.app.domain

/**
 * キャラの種別(猫 / 犬)。ピッカー上部のセグメント切替に使う。iOS `PetSpecies` の移植。
 */
enum class PetSpecies(val rawValue: String, val displayName: String) {
    Cat("cat", "猫"),
    Dog("dog", "犬");

    companion object {
        fun fromRaw(raw: String?): PetSpecies = entries.firstOrNull { it.rawValue == raw } ?: Cat
    }
}

/**
 * 犬の種類(5 種)。iOS `DogBreed` の移植。`CatBreed` と同じ API 面を持ち、drawable は
 * `dog_<breed>_<state>`(全 lowercase。例: dog_shiba_waitingmorning)。猫と同じ 10 ポーズをそろえる。
 */
enum class DogBreed(val rawValue: String, val displayName: String, val tintArgb: Long) {
    Shiba("shiba", "柴犬", 0xFFE08C4C),
    Chihuahua("chihuahua", "チワワ", 0xFFD9AE73),
    ToyPoodle("toypoodle", "トイプードル", 0xFFEBD2A6),
    Golden("golden", "ゴールデン", 0xFFF2B85A),
    Bulldog("bulldog", "ブルドッグ", 0xFFE0CCB3),
    Dachshund("dachshund", "ダックス", 0xFFB36B47),
    Corgi("corgi", "コーギー", 0xFFE69E61),
    Schnauzer("schnauzer", "シュナウザー", 0xFF8C8C94),
    Pomeranian("pomeranian", "ポメラニアン", 0xFFF2B366);

    fun assetName(state: CatState): String = "dog_${rawValue}_${state.rawValue.lowercase()}"
    val avatarAssetName: String get() = "dog_${rawValue}_waitingmorning"
    val shakerAssetName: String get() = "dog_${rawValue}_waitingmorning_shaker"

    companion object {
        val Default = Shiba
        fun fromRaw(raw: String?): DogBreed = entries.firstOrNull { it.rawValue == raw } ?: Default

        /** 生成漏れ時のフォールバック(柴犬の同 state)。iOS DogBreed.fallbackAssetName 相当。 */
        fun fallbackAssetName(state: CatState): String = "dog_shiba_${state.rawValue.lowercase()}"
        const val FALLBACK_AVATAR: String = "dog_shiba_waitingmorning"
    }
}

/**
 * ユーザーが選べるキャラ。猫(11 種)か犬(5 種)のどちらか。iOS `PetBreed` の移植。
 * `CatBreed` と同一の API 面(assetName/avatar/shaker/tint/displayName/randomHappyPose)を露出し、
 * 描画側が `catBreed` を `pet` に置き換えるだけで犬も描けるようにする。
 */
sealed class PetBreed {
    data class Cat(val breed: CatBreed) : PetBreed()
    data class Dog(val breed: DogBreed) : PetBreed()

    val species: PetSpecies
        get() = when (this) {
            is Cat -> PetSpecies.Cat
            is Dog -> PetSpecies.Dog
        }

    val displayName: String
        get() = when (this) {
            is Cat -> breed.displayName
            is Dog -> breed.displayName
        }

    val tintArgb: Long
        get() = when (this) {
            is Cat -> breed.tintArgb
            is Dog -> breed.tintArgb
        }

    fun assetName(state: CatState): String = when (this) {
        is Cat -> breed.assetName(state)
        is Dog -> breed.assetName(state)
    }

    val avatarAssetName: String
        get() = when (this) {
            is Cat -> breed.avatarAssetName
            is Dog -> breed.avatarAssetName
        }

    val shakerAssetName: String
        get() = when (this) {
            is Cat -> breed.shakerAssetName
            is Dog -> breed.shakerAssetName
        }

    /** 種別に応じた state フォールバック asset(同種の既定 → 最終 orange 猫)。 */
    fun fallbackAssetName(state: CatState): String = when (this) {
        is Cat -> CatBreed.fallbackAssetName(state)
        is Dog -> DogBreed.fallbackAssetName(state)
    }

    /**
     * 共有カード用ハッピーポーズ(celebrating/happy2/happy3)を seed で決定的に1つ選ぶ。
     * 実在する drawable のみ対象。皆無なら同種の既定 celebrating にフォールバック。
     */
    fun randomHappyPoseAsset(seed: Int, exists: (String) -> Boolean): String {
        val prefix = when (this) {
            is Cat -> "cat_${breed.rawValue}"
            is Dog -> "dog_${breed.rawValue}"
        }
        val candidates = CatBreed.HAPPY_POSE_SUFFIXES.map { "${prefix}_$it" }.filter(exists)
        if (candidates.isEmpty()) {
            return if (species == PetSpecies.Dog) "dog_shiba_celebrating" else "cat_orange_celebrating"
        }
        return candidates[Math.floorMod(seed, candidates.size)]
    }

    /** "cat:orange" / "dog:shiba" 形式の永続化文字列。 */
    val storageValue: String
        get() = when (this) {
            is Cat -> "cat:${breed.rawValue}"
            is Dog -> "dog:${breed.rawValue}"
        }

    /**
     * 友達公開プロフィール(Supabase `my_cat_breed` text 列)に載せる文字列。iOS `friendBreedString` 相当。
     * 猫は**従来どおり素の rawValue**("orange")で旧クライアント互換を保ち、犬だけ "dog:shiba" 形式にする
     * (旧クライアントはパース不能→既定猫にフォールバック=破綻なし)。列追加マイグレーション不要。
     */
    val friendBreedString: String
        get() = when (this) {
            is Cat -> breed.rawValue
            is Dog -> "dog:${breed.rawValue}"
        }

    companion object {
        val Default: PetBreed = Cat(CatBreed.Default)

        /** "cat:orange"/"dog:shiba"、または旧形式(prefix 無し=猫 rawValue)から復元。 */
        fun fromStorage(raw: String?): PetBreed {
            if (raw.isNullOrBlank()) return Default
            val parts = raw.split(":", limit = 2)
            if (parts.size != 2) {
                // 旧形式救済(prefix 無し = 猫の rawValue)。
                return Cat(CatBreed.fromRaw(raw))
            }
            return when (parts[0]) {
                "dog" -> Dog(DogBreed.fromRaw(parts[1]))
                else -> Cat(CatBreed.fromRaw(parts[1]))
            }
        }
    }
}

/**
 * キャラ選択のロック判定(課金解放)。猫犬どちらにも効く `CatBreedAccess` の汎用版。
 * 無料は「今のキャラ」以外ロック。紹介⭐10解放 or プレミアムで全解放。iOS `PetBreedAccess` 相当。
 */
object PetBreedAccess {
    fun isLocked(
        breed: PetBreed,
        current: PetBreed,
        isPremium: Boolean,
        referralUnlocked: Boolean,
    ): Boolean = !isPremium && !referralUnlocked && breed != current
}
