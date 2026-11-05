package joel.scripturememory.model

import java.io.File
import java.sql.DriverManager

object JdbcAnkiDatabase : AnkiDatabaseOpener {
    override fun open(file: File): AnkiDatabase {
        val connection = DriverManager.getConnection("jdbc:sqlite:${file.path}")
        return object : AnkiDatabase {
            override fun rows(sql: String): List<List<Any?>> =
                connection.createStatement().use { statement ->
                    statement.executeQuery(sql).use { result ->
                        val columns = result.metaData.columnCount
                        val rows = mutableListOf<List<Any?>>()
                        while (result.next()) rows += (1..columns).map { result.getObject(it) }
                        rows
                    }
                }

            override fun execute(sql: String) {
                connection.createStatement().use { it.execute(sql) }
            }

            override fun close() = connection.close()
        }
    }
}
