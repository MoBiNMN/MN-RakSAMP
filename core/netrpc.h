#define REJECT_REASON_BAD_VERSION 1
#define REJECT_REASON_BAD_NICKNAME 2
#define REJECT_REASON_BAD_MOD 3
#define REJECT_REASON_BAD_PLAYERID 4

#define MAX_MENU_ITEMS 12
#define MAX_MENU_LINE 32
#define MAX_COLUMNS 2
struct MENU_INT
{
	BOOL bMenu;
	BOOL bRow[MAX_MENU_ITEMS];
	BOOL bPadding[8 - ((MAX_MENU_ITEMS + 1) % 8)];
};
struct stGTAMenu
{
	char szTitle[MAX_MENU_LINE];
	char szSeparator[MAX_MENU_LINE];
	BYTE byteColCount;
	char szColumnContent[MAX_COLUMNS][MAX_MENU_LINE];
};

#define IDB_BUTTON1 10
#define IDB_BUTTON2 11
#define IDE_INPUTEDIT 12
#define IDL_LISTBOX 13

#define DIALOG_STYLE_MSGBOX 0
#define DIALOG_STYLE_INPUT 1
#define DIALOG_STYLE_LIST 2
#define DIALOG_STYLE_PASSWORD 3

extern void RegisterRPCs(MNRakSampContext *ctx);
