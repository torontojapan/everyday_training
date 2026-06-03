package com.goexercise.app.di

import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import java.time.Clock
import javax.inject.Singleton

/** アプリ全体の共通依存。`Clock` を注入可能にして時刻依存ロジックをテスト可能に保つ。 */
@Module
@InstallIn(SingletonComponent::class)
object AppModule {
    @Provides
    @Singleton
    fun provideClock(): Clock = Clock.systemDefaultZone()
}
