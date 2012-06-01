<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output encoding="iso-8859-1"/>
  <xsl:template match="/">
    <html>
      <head>
      </head>
      <body>
        <h2>Issues</h2>
        <table border="1">
          <tr>
            <th>Id</th>
            <th>Status</th>
            <th>Start Date</th>
            <th>Subject</th>
          </tr>
          <xsl:for-each select="issues/issue">
            <tr>
              <td>
                <xsl:value-of select="id"/>
              </td>
              <td>
                <xsl:value-of select="status/@name"/>
              </td>
              <td>
                <xsl:value-of select="start_date"/>
              </td>
              <td>
                <xsl:value-of select="subject"/>
              </td>
            </tr>
          </xsl:for-each>
        </table>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
