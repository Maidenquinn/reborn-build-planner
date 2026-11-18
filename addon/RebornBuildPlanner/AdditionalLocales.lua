-- Additional client languages: high-frequency navigation terms only.
-- Missing keys intentionally fall back to English through Locale.T.
-- Keep English authoritative; do not claim full translations for these locales.
local ADDON, ns = ...
local register = ns.Locale.RegisterLanguage

register("deDE", {
  ["Language"]="Sprache", ["Search:"]="Suchen:", ["Create a build"]="Build erstellen",
  ["Save"]="Speichern", ["Cancel"]="Abbrechen", ["Close"]="Schließen",
  ["Import"]="Importieren", ["Export"]="Exportieren", ["Delete"]="Löschen",
  ["Duplicate"]="Duplizieren", ["Rename"]="Umbenennen", ["Spells"]="Zauber",
  ["Rings"]="Ringe", ["Trinkets"]="Schmuckstücke", ["Amulet"]="Amulett",
  ["Jewelry"]="Schmuck", ["Class"]="Klasse", ["Class:"]="Klasse:",
  ["All classes"]="Alle Klassen", ["Name:"]="Name:", ["Unsaved changes"]="Ungespeicherte Änderungen",
  ["Discard"]="Verwerfen", ["Keep editing"]="Weiter bearbeiten", ["Details"]="Details"
})
register("esES", {
  ["Language"]="Idioma", ["Search:"]="Buscar:", ["Create a build"]="Crear configuración",
  ["Save"]="Guardar", ["Cancel"]="Cancelar", ["Close"]="Cerrar",
  ["Import"]="Importar", ["Export"]="Exportar", ["Delete"]="Eliminar",
  ["Duplicate"]="Duplicar", ["Rename"]="Renombrar", ["Spells"]="Hechizos",
  ["Rings"]="Anillos", ["Trinkets"]="Abalorios", ["Amulet"]="Amuleto",
  ["Jewelry"]="Joyas", ["Class"]="Clase", ["Class:"]="Clase:",
  ["All classes"]="Todas las clases", ["Name:"]="Nombre:", ["Unsaved changes"]="Cambios sin guardar",
  ["Discard"]="Descartar", ["Keep editing"]="Seguir editando", ["Details"]="Detalles"
})
register("ptBR", {
  ["Language"]="Idioma", ["Search:"]="Pesquisar:", ["Create a build"]="Criar build",
  ["Save"]="Salvar", ["Cancel"]="Cancelar", ["Close"]="Fechar",
  ["Import"]="Importar", ["Export"]="Exportar", ["Delete"]="Excluir",
  ["Duplicate"]="Duplicar", ["Rename"]="Renomear", ["Spells"]="Feitiços",
  ["Rings"]="Anéis", ["Trinkets"]="Berloques", ["Amulet"]="Amuleto",
  ["Jewelry"]="Joias", ["Class"]="Classe", ["Class:"]="Classe:",
  ["All classes"]="Todas as classes", ["Name:"]="Nome:", ["Unsaved changes"]="Alterações não salvas",
  ["Discard"]="Descartar", ["Keep editing"]="Continuar editando", ["Details"]="Detalhes"
})
register("plPL", {
  ["Language"]="Język", ["Search:"]="Szukaj:", ["Create a build"]="Utwórz konfigurację",
  ["Save"]="Zapisz", ["Cancel"]="Anuluj", ["Close"]="Zamknij",
  ["Import"]="Importuj", ["Export"]="Eksportuj", ["Delete"]="Usuń",
  ["Duplicate"]="Duplikuj", ["Rename"]="Zmień nazwę", ["Spells"]="Zaklęcia",
  ["Rings"]="Pierścienie", ["Trinkets"]="Talizmany", ["Amulet"]="Amulet",
  ["Jewelry"]="Biżuteria", ["Class"]="Klasa", ["Class:"]="Klasa:",
  ["All classes"]="Wszystkie klasy", ["Name:"]="Nazwa:", ["Unsaved changes"]="Niezapisane zmiany",
  ["Discard"]="Odrzuć", ["Keep editing"]="Kontynuuj edycję", ["Details"]="Szczegóły"
})
register("csCZ", {
  ["Language"]="Jazyk", ["Search:"]="Hledat:", ["Create a build"]="Vytvořit sestavu",
  ["Save"]="Uložit", ["Cancel"]="Zrušit", ["Close"]="Zavřít",
  ["Import"]="Importovat", ["Export"]="Exportovat", ["Delete"]="Smazat",
  ["Duplicate"]="Duplikovat", ["Rename"]="Přejmenovat", ["Spells"]="Kouzla",
  ["Rings"]="Prsteny", ["Trinkets"]="Doplňky", ["Amulet"]="Amulet",
  ["Jewelry"]="Šperky", ["Class"]="Třída", ["Class:"]="Třída:",
  ["All classes"]="Všechny třídy", ["Name:"]="Název:", ["Unsaved changes"]="Neuložené změny",
  ["Discard"]="Zahodit", ["Keep editing"]="Pokračovat v úpravách", ["Details"]="Podrobnosti"
})
register("roRO", {
  ["Language"]="Limbă", ["Search:"]="Caută:", ["Create a build"]="Creează un build",
  ["Save"]="Salvează", ["Cancel"]="Anulează", ["Close"]="Închide",
  ["Import"]="Importă", ["Export"]="Exportă", ["Delete"]="Șterge",
  ["Duplicate"]="Duplică", ["Rename"]="Redenumește", ["Spells"]="Vrăji",
  ["Rings"]="Inele", ["Trinkets"]="Talismane", ["Amulet"]="Amuletă",
  ["Jewelry"]="Bijuterii", ["Class"]="Clasă", ["Class:"]="Clasă:",
  ["All classes"]="Toate clasele", ["Name:"]="Nume:", ["Unsaved changes"]="Modificări nesalvate",
  ["Discard"]="Renunță", ["Keep editing"]="Continuă editarea", ["Details"]="Detalii"
})
register("trTR", {
  ["Language"]="Dil", ["Search:"]="Ara:", ["Create a build"]="Dizilim oluştur",
  ["Save"]="Kaydet", ["Cancel"]="İptal", ["Close"]="Kapat",
  ["Import"]="İçe aktar", ["Export"]="Dışa aktar", ["Delete"]="Sil",
  ["Duplicate"]="Kopyala", ["Rename"]="Yeniden adlandır", ["Spells"]="Büyüler",
  ["Rings"]="Yüzükler", ["Trinkets"]="Aksesuarlar", ["Amulet"]="Muska",
  ["Jewelry"]="Takılar", ["Class"]="Sınıf", ["Class:"]="Sınıf:",
  ["All classes"]="Tüm sınıflar", ["Name:"]="Ad:", ["Unsaved changes"]="Kaydedilmemiş değişiklikler",
  ["Discard"]="Vazgeç", ["Keep editing"]="Düzenlemeye devam et", ["Details"]="Ayrıntılar"
})
register("ruRU", {
  ["Language"]="Язык", ["Search:"]="Поиск:", ["Create a build"]="Создать сборку",
  ["Save"]="Сохранить", ["Cancel"]="Отмена", ["Close"]="Закрыть",
  ["Import"]="Импорт", ["Export"]="Экспорт", ["Delete"]="Удалить",
  ["Duplicate"]="Дублировать", ["Rename"]="Переименовать", ["Spells"]="Заклинания",
  ["Rings"]="Кольца", ["Trinkets"]="Аксессуары", ["Amulet"]="Амулет",
  ["Jewelry"]="Украшения", ["Class"]="Класс", ["Class:"]="Класс:",
  ["All classes"]="Все классы", ["Name:"]="Название:", ["Unsaved changes"]="Несохранённые изменения",
  ["Discard"]="Отменить изменения", ["Keep editing"]="Продолжить", ["Details"]="Подробности"
})
register("ukUA", {
  ["Language"]="Мова", ["Search:"]="Пошук:", ["Create a build"]="Створити збірку",
  ["Save"]="Зберегти", ["Cancel"]="Скасувати", ["Close"]="Закрити",
  ["Import"]="Імпорт", ["Export"]="Експорт", ["Delete"]="Видалити",
  ["Duplicate"]="Дублювати", ["Rename"]="Перейменувати", ["Spells"]="Заклинання",
  ["Rings"]="Каблучки", ["Trinkets"]="Аксесуари", ["Amulet"]="Амулет",
  ["Jewelry"]="Прикраси", ["Class"]="Клас", ["Class:"]="Клас:",
  ["All classes"]="Усі класи", ["Name:"]="Назва:", ["Unsaved changes"]="Незбережені зміни",
  ["Discard"]="Відхилити зміни", ["Keep editing"]="Продовжити редагування", ["Details"]="Подробиці"
})
register("zhCN", {
  ["Language"]="语言", ["Search:"]="搜索：", ["Create a build"]="创建配装",
  ["Save"]="保存", ["Cancel"]="取消", ["Close"]="关闭",
  ["Import"]="导入", ["Export"]="导出", ["Delete"]="删除",
  ["Duplicate"]="复制", ["Rename"]="重命名", ["Spells"]="法术",
  ["Rings"]="戒指", ["Trinkets"]="饰品", ["Amulet"]="护符",
  ["Jewelry"]="首饰", ["Class"]="职业", ["Class:"]="职业：",
  ["All classes"]="所有职业", ["Name:"]="名称：", ["Unsaved changes"]="未保存的修改",
  ["Discard"]="放弃修改", ["Keep editing"]="继续编辑", ["Details"]="详情"
})
register("jaJP", {
  ["Language"]="言語", ["Search:"]="検索：", ["Create a build"]="ビルドを作成",
  ["Save"]="保存", ["Cancel"]="キャンセル", ["Close"]="閉じる",
  ["Import"]="インポート", ["Export"]="エクスポート", ["Delete"]="削除",
  ["Duplicate"]="複製", ["Rename"]="名前を変更", ["Spells"]="呪文",
  ["Rings"]="指輪", ["Trinkets"]="装飾品", ["Amulet"]="アミュレット",
  ["Jewelry"]="宝飾品", ["Class"]="クラス", ["Class:"]="クラス：",
  ["All classes"]="すべてのクラス", ["Name:"]="名前：", ["Unsaved changes"]="未保存の変更",
  ["Discard"]="変更を破棄", ["Keep editing"]="編集を続ける", ["Details"]="詳細"
})
register("koKR", {
  ["Language"]="언어", ["Search:"]="검색:", ["Create a build"]="빌드 만들기",
  ["Save"]="저장", ["Cancel"]="취소", ["Close"]="닫기",
  ["Import"]="가져오기", ["Export"]="내보내기", ["Delete"]="삭제",
  ["Duplicate"]="복제", ["Rename"]="이름 변경", ["Spells"]="주문",
  ["Rings"]="반지", ["Trinkets"]="장신구", ["Amulet"]="부적",
  ["Jewelry"]="장신구", ["Class"]="직업", ["Class:"]="직업:",
  ["All classes"]="모든 직업", ["Name:"]="이름:", ["Unsaved changes"]="저장되지 않은 변경 사항",
  ["Discard"]="변경 사항 버리기", ["Keep editing"]="편집 계속", ["Details"]="세부 정보"
})
