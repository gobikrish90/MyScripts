using System;
using System.Windows.Forms;

namespace InstallationMaster
{
    static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main()
        {
            // Initializes the standard Windows styling
            Application.SetHighDpiMode(HighDpiMode.SystemAware);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            // CRITICAL LINE: This launches the MainForm. Without this, the app exits immediately.
            Application.Run(new MainForm());
        }
    }
}