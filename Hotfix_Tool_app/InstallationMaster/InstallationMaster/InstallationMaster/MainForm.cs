using System;
using System.Drawing;
using System.IO;
using System.Diagnostics;
using System.Windows.Forms;

namespace InstallationMaster
{
    public partial class MainForm : Form
    {
        private const string BaseDir = @"C:\pnxtemp\ProPhoenixSuite";
        private Label lblStatus;

        public MainForm()
        {
            SetupCustomUI();
            if (!Directory.Exists(BaseDir)) Directory.CreateDirectory(BaseDir);
        }

        private void SetupCustomUI()
        {
            this.Text = "ProPhoenix Master Launcher";
            this.Size = new Size(600, 750);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.BackColor = Color.FromArgb(30, 30, 30);
            this.ForeColor = Color.White;

            Label lblTitle = new Label();
            lblTitle.Text = "TOOL SELECTOR";
            lblTitle.Font = new Font("Segoe UI", 20, FontStyle.Bold);
            lblTitle.ForeColor = Color.Cyan;
            lblTitle.TextAlign = ContentAlignment.MiddleCenter;
            lblTitle.Size = new Size(600, 50);
            lblTitle.Location = new Point(0, 40);
            this.Controls.Add(lblTitle);

            // BUTTONS
            CreateButton("Hotfix Update - Demo / Test", Color.Orange, 130, "Autodefinedproducts_Vers3.1.ps1", ScriptRepository.Content_DemoTest);
            CreateButton("DB Sync Update", Color.FromArgb(0, 122, 204), 230, "Autodbsync_v3.5_GUI.ps1", ScriptRepository.Content_DBSync);
            CreateButton("Hotfix Update - PD CAD", Color.Crimson, 330, "Cad_Hotfixupdate_v2.0.ps1", ScriptRepository.Content_CAD);

            lblStatus = new Label();
            lblStatus.Text = "Ready.";
            lblStatus.ForeColor = Color.Gray;
            lblStatus.TextAlign = ContentAlignment.MiddleCenter;
            lblStatus.Size = new Size(600, 30);
            lblStatus.Location = new Point(0, 600);
            this.Controls.Add(lblStatus);
        }

        private void CreateButton(string text, Color color, int y, string filename, string content)
        {
            Button btn = new Button();
            btn.Text = text;
            btn.BackColor = color;
            btn.ForeColor = Color.Black;
            if (color.R < 100) btn.ForeColor = Color.White; // Adjust text color for dark buttons
            btn.Font = new Font("Segoe UI", 14, FontStyle.Bold);
            btn.Size = new Size(450, 70);
            btn.Location = new Point((600 - 450) / 2, y);
            btn.FlatStyle = FlatStyle.Flat;
            btn.Click += (s, e) => LaunchTool(filename, content);
            this.Controls.Add(btn);
        }

        private void LaunchTool(string fileName, string content)
        {
            try
            {
                lblStatus.Text = $"Launching {fileName}...";
                string fullPath = Path.Combine(BaseDir, fileName);
                File.WriteAllText(fullPath, content);

                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "powershell.exe";
                // -NoExit keeps the window open so you can see details/errors
                psi.Arguments = $"-NoExit -ExecutionPolicy Bypass -File \"{fullPath}\"";
                psi.Verb = "runas";
                psi.UseShellExecute = true;

                Process.Start(psi);
                lblStatus.Text = "Launched Successfully.";
                lblStatus.ForeColor = Color.Lime;
            }
            catch (Exception ex)
            {
                lblStatus.Text = "Error.";
                MessageBox.Show(ex.Message);
            }
        }
    }
}